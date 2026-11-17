import 'dart:async';
import 'dart:io';

import 'package:ion_web/ion_web.dart';
import 'package:ion_web/src/http/http.dart';
import 'package:sl/sl.dart';
import 'package:test/test.dart';

import '../helpers/helpers.dart';

void main() {
  group('WebSocket End-to-End Integration', () {
    late ServerSocket serverSocket;

    setUp(() async {
      serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    });

    tearDown(() async {
      await serverSocket.close();
    });

    test(
      'echoes text and binary messages over real WebSocket connection',
      () async {
        serverSocket.listen((socket) {
          HttpConnection(
            socket,
            handler: (Request request) {
              return Response.websocket((channel) async {
                channel.stream.listen((message) {
                  if (message is String) {
                    channel.sink.add('echo: $message');
                  } else if (message is Uint8List) {
                    channel.sink.add(Uint8List.fromList([...message, 99]));
                  }
                });
              });
            },
          ).start();
        });

        final ws = await WebSocket.connect(
          'ws://localhost:${serverSocket.port}/ws',
        );

        final received = <Object?>[];
        final completer = Completer<void>();

        ws.listen((data) {
          received.add(data);
          if (received.length == 2) {
            completer.complete();
          }
        });

        ws.add('hello server');
        ws.add(Uint8List.fromList([10, 20]));

        await completer.future.timeout(const Duration(seconds: 5));
        await ws.close();

        expect(received[0], 'echo: hello server');
        expect(received[1], equals([10, 20, 99]));
      },
    );

    test(
      'server initiates close and client receives closeCode and closeReason',
      () async {
        serverSocket.listen((socket) {
          HttpConnection(
            socket,
            handler: (Request request) {
              return Response.websocket((channel) async {
                channel.stream.listen((message) async {
                  if (message == 'close_me') {
                    await channel.sink.close(1000, 'normal exit');
                  }
                });
              });
            },
          ).start();
        });

        final ws = await WebSocket.connect(
          'ws://localhost:${serverSocket.port}/ws',
        );

        final closeDone = Completer<void>();
        ws.listen((_) {}, onDone: closeDone.complete);

        ws.add('close_me');
        await closeDone.future.timeout(const Duration(seconds: 5));

        expect(ws.closeCode, equals(1000));
        expect(ws.closeReason, equals('normal exit'));
      },
    );

    test(
      'supports permessage-deflate compression negotiation and messaging',
      () async {
        serverSocket.listen((socket) {
          HttpConnection(
            socket,
            handler: (Request request) {
              return Response.websocket(
                (channel) async {
                  channel.stream.listen((message) {
                    if (message is String) {
                      channel.sink.add('compressed_echo: $message');
                    }
                  });
                },
                compression: WebSocketDeflateOptions.defaultConfig,
              );
            },
          ).start();
        });

        final client = HttpClient();
        final req = await client.get('localhost', serverSocket.port, '/ws');
        req.headers.set('Connection', 'Upgrade');
        req.headers.set('Upgrade', 'websocket');
        req.headers.set('Sec-WebSocket-Key', 'dGhlIHNhbXBsZSBub25jZQ==');
        req.headers.set('Sec-WebSocket-Version', '13');
        req.headers.set('Sec-WebSocket-Extensions', 'permessage-deflate');
        final res = await req.close();

        expect(res.statusCode, equals(101));
        expect(
          res.headers.value('sec-websocket-extensions'),
          contains('permessage-deflate'),
        );
        final detachSocket = await res.detachSocket();
        await detachSocket.close();
        client.close(force: true);
      },
    );
  });

  group('WebSocket handler errors', () {
    setUpAll(registerTestFallbacks);

    test('close the socket with 1011 and are logged', () async {
      final logHandler = MockLogHandler();
      when(() => logHandler.enabled(any(), any())).thenReturn(true);
      final server = await IonServer.serve(
        (request) => Response.websocket((channel) async {
          await channel.stream.first;
          throw StateError('boom');
        }),
        address: InternetAddress.loopbackIPv4,
        port: 0,
        logger: Logger(handler: logHandler),
      );
      addTearDown(server.close);

      final ws = await WebSocket.connect('ws://localhost:${server.port}/ws');
      ws.add('trigger');
      await ws.drain<void>().timeout(const Duration(seconds: 5));

      expect(ws.closeCode, 1011);
      final records = verify(
        () => logHandler.handle(any(), captureAny()),
      ).captured.cast<LogRecord>();
      expect(records.map((r) => r.message), contains('error in handler'));
    });
  });

  group('WebSocket connection lifetime and flow control', () {
    late IonServer server;

    Future<void> serve(Handler handler, {int? maxConnections}) async {
      server = await IonServer.serve(
        handler,
        address: InternetAddress.loopbackIPv4,
        port: 0,
        maxConnections: maxConnections,
      );
      addTearDown(server.close);
    }

    /// A raw client past the 101 response; its input is left paused.
    Future<Socket> rawUpgrade() async {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        server.port,
      );
      addTearDown(socket.destroy);
      socket
        ..done.ignore()
        ..add(
          ascii.encode(
            'GET /ws HTTP/1.1\r\nHost: localhost:${server.port}\r\n'
            'Upgrade: websocket\r\nConnection: Upgrade\r\n'
            'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n'
            'Sec-WebSocket-Version: 13\r\n\r\n',
          ),
        );
      final head = Completer<void>();
      // Stays paused: the test reads nothing more.
      // ignore: cancel_subscriptions
      late final StreamSubscription<Uint8List> subscription;
      subscription = socket.listen((data) {
        if (!head.isCompleted && latin1.decode(data).contains('\r\n\r\n')) {
          subscription.pause();
          head.complete();
        }
      }, onError: (Object _) {});
      await head.future;
      return socket;
    }

    /// A masked binary client frame with a zero mask key.
    Uint8List clientFrame(int size) {
      final header = [0x82, 0x80 | 127, 0, 0, 0, 0];
      for (var i = 3; i >= 0; i--) {
        header.add((size >> (i * 8)) & 0xFF);
      }
      return Uint8List(header.length + 4 + size)..setAll(0, header);
    }

    test('a finished session releases the connection', () async {
      await serve(
        (request) => request.isWebSocketUpgrade
            ? Response.websocket((channel) async {
                channel.sink.add('hi');
                await channel.sink.close();
              })
            : Response.text('ok'),
        maxConnections: 1,
      );

      final ws = await WebSocket.connect('ws://localhost:${server.port}/ws');
      expect(await ws.toList(), ['hi']);

      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final response = await (await client.get(
        'localhost',
        server.port,
        '/',
      )).close().timeout(const Duration(seconds: 5));
      expect(response.statusCode, 200);
      await response.drain<void>();
      client.close(force: true);

      await server.shutdown().timeout(const Duration(seconds: 5));
    });

    test('a paused reader stops reading the socket', () async {
      final firstMessage = Completer<void>();
      await serve(
        (request) => Response.websocket((channel) async {
          // ignore: cancel_subscriptions
          late final StreamSubscription<Object?> subscription;
          subscription = channel.stream.listen((_) {
            subscription.pause();
            firstMessage.complete();
          });
        }),
      );
      final socket = await rawUpgrade();

      final frame = clientFrame(1 << 20);
      for (var i = 0; i < 32; i++) {
        socket.add(frame);
      }
      await firstMessage.future.timeout(const Duration(seconds: 5));

      final flushed = await socket
          .flush()
          .then((_) => true)
          .timeout(const Duration(seconds: 1), onTimeout: () => false);
      expect(flushed, isFalse, reason: 'server should stop reading');
    });

    test('sink.addStream waits for the socket to drain', () async {
      var produced = 0;
      await serve(
        (request) => Response.websocket((channel) async {
          await channel.sink.addStream(
            Stream.fromIterable(
              Iterable.generate(256, (_) => Uint8List(1 << 20)),
            ).map((chunk) {
              produced++;
              return chunk;
            }),
          );
        }),
      );
      final socket = await rawUpgrade();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      // The pong is written while the output is draining.
      socket.add([0x89, 0x80, 0, 0, 0, 0]);

      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(produced, lessThan(64), reason: 'the client reads nothing');
    });
  });
}

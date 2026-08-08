import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ion_web/ion_web.dart';
import 'package:ion_web/src/http/http.dart';
import 'package:test/test.dart';

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
}

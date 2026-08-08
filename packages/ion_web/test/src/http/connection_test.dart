import 'dart:async';
import 'dart:io';

import 'package:ion_web/ion_web.dart';
import 'package:ion_web/src/http/http.dart';
import 'package:sl/sl.dart';
import 'package:test/test.dart';

import '../../helpers/helpers.dart';

void main() {
  setUpAll(registerTestFallbacks);

  group('HttpConnection integration', () {
    late ServerSocket serverSocket;

    setUp(() async {
      serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    });

    tearDown(() async {
      await serverSocket.close();
    });

    test(
      'populates Request method, uri, connectionInfo, and context',
      () async {
        HttpMethod? capturedMethod;
        Uri? capturedUri;
        ConnectionInfo? capturedConnectionInfo;
        bool? isContextDone;

        const requestText =
            'POST /api/test?param=1 HTTP/1.1\r\n'
            'Host: localhost\r\n'
            'Connection: close\r\n'
            'Content-Length: 2\r\n'
            '\r\n'
            'hi';

        await sendConnectionRequest(
          serverSocket,
          requestText,
          handler: (Request request) async {
            capturedMethod = request.method;
            capturedUri = request.uri;
            capturedConnectionInfo = request.connectionInfo;

            unawaited(
              request.ctx.done.then((_) {
                isContextDone = true;
              }),
            );

            return Response.bytes(stringToBytes('OK'));
          },
        );

        expect(capturedMethod, HttpMethod.post);
        expect(capturedUri.toString(), 'http://localhost/api/test?param=1');
        expect(capturedConnectionInfo, isNotNull);
        expect(capturedConnectionInfo!.remoteAddress.address, '127.0.0.1');
        expect(capturedConnectionInfo!.localPort, serverSocket.port);
        expect(isContextDone, isTrue);
      },
    );

    test('handles fixed length POST request body stream', () async {
      String? receivedBody;

      const requestText =
          'POST /echo HTTP/1.1\r\n'
          'Host: localhost\r\n'
          'Connection: close\r\n'
          'Content-Length: 11\r\n'
          '\r\n'
          'Hello World';

      final responseText = await sendConnectionRequest(
        serverSocket,
        requestText,
        handler: (Request request) async {
          receivedBody = await readStreamText(request);
          return Response.bytes(stringToBytes('OK'));
        },
      );

      expect(receivedBody, 'Hello World');
      expect(responseText, contains('200 OK'));
    });

    test('handles chunked POST request body stream', () async {
      String? receivedBody;

      const requestText =
          'POST /chunked HTTP/1.1\r\n'
          'Host: localhost\r\n'
          'Connection: close\r\n'
          'Transfer-Encoding: chunked\r\n'
          '\r\n'
          '5\r\nhello\r\n'
          '6\r\n world\r\n'
          '0\r\n\r\n';

      final responseText = await sendConnectionRequest(
        serverSocket,
        requestText,
        handler: (Request request) async {
          receivedBody = await readStreamText(request);
          return Response.bytes(stringToBytes('OK'));
        },
      );

      expect(receivedBody, 'hello world');
      expect(responseText, contains('200 OK'));
    });

    test(
      'returns 400 Bad Request on conflicting body headers',
      () async {
        const requestText =
            'POST /conflict HTTP/1.1\r\n'
            'Host: localhost\r\n'
            'Content-Length: 5\r\n'
            'Transfer-Encoding: chunked\r\n'
            '\r\n'
            'hello';

        final responseText = await sendConnectionRequest(
          serverSocket,
          requestText,
          handler: (Request request) async =>
              Response.bytes(stringToBytes('OK')),
        );

        expect(responseText, contains('400 Bad Request'));
      },
    );

    test(
      'returns 400 Bad Request on invalid Host header for HTTP/1.1',
      () async {
        const requestText =
            'GET / HTTP/1.1\r\n'
            'Host: user@host/path\r\n'
            '\r\n';

        final responseText = await sendConnectionRequest(
          serverSocket,
          requestText,
          handler: (Request request) async =>
              Response.bytes(stringToBytes('OK')),
        );

        expect(responseText, contains('400 Bad Request'));
      },
    );

    test(
      'returns 400 Bad Request on malformed HTTP request (HttpParserException)',
      () async {
        const requestText =
            'GET / HTTP/1.1\n' // Missing CR before LF
            'Host: localhost\r\n'
            '\r\n';

        final responseText = await sendConnectionRequest(
          serverSocket,
          requestText,
          handler: (Request request) async =>
              Response.bytes(stringToBytes('OK')),
        );

        expect(responseText, contains('400 Bad Request'));
      },
    );

    test('returns 405 Method Not Allowed on CONNECT method', () async {
      const requestText =
          'CONNECT example.com:443 HTTP/1.1\r\n'
          'Host: example.com:443\r\n'
          '\r\n';

      final responseText = await sendConnectionRequest(
        serverSocket,
        requestText,
        handler: (Request request) async => Response.bytes(stringToBytes('OK')),
      );

      expect(responseText, contains('405 Method Not Allowed'));
    });

    test('handles streaming Response.stream over socket connection', () async {
      const requestText =
          'GET /stream HTTP/1.1\r\n'
          'Host: localhost\r\n'
          'Connection: close\r\n'
          '\r\n';

      final responseText = await sendConnectionRequest(
        serverSocket,
        requestText,
        handler: (Request request) async {
          Stream<Uint8List> stream() async* {
            yield stringToBytes('chunk1-');
            yield stringToBytes('chunk2');
          }

          return Response.stream(stream());
        },
      );

      expect(responseText, contains('HTTP/1.1 200 OK\r\n'));
      expect(responseText, contains('Transfer-Encoding: chunked\r\n'));
      expect(
        responseText,
        contains('7\r\nchunk1-\r\n6\r\nchunk2\r\n0\r\n\r\n'),
      );
    });

    test(
      'cancels req.ctx and stops SSE generator on client disconnect',
      () async {
        final contextDoneCompleter = Completer<void>();
        final generatorCancelledCompleter = Completer<void>();
        var eventsSent = 0;

        serverSocket.listen((socket) {
          final connection = HttpConnection(
            socket,
            handler: (Request request) async {
              unawaited(
                request.ctx.done.then((_) {
                  if (!contextDoneCompleter.isCompleted) {
                    contextDoneCompleter.complete();
                  }
                }),
              );

              return Response.sse(() async* {
                try {
                  while (request.ctx.error == null) {
                    eventsSent++;
                    yield SseEvent.text('event-$eventsSent');
                    await Future<void>.delayed(
                      const Duration(milliseconds: 20),
                    );
                  }
                } finally {
                  if (!generatorCancelledCompleter.isCompleted) {
                    generatorCancelledCompleter.complete();
                  }
                }
              });
            },
          );
          connection.start();
        });

        final client = await Socket.connect(
          InternetAddress.loopbackIPv4,
          serverSocket.port,
        );

        const requestText =
            'GET /sse HTTP/1.1\r\n'
            'Host: localhost\r\n'
            '\r\n';

        client.add(stringToBytes(requestText));

        final firstChunkCompleter = Completer<void>();
        final subscription = client.listen((data) {
          if (!firstChunkCompleter.isCompleted) {
            firstChunkCompleter.complete();
          }
        });

        await firstChunkCompleter.future;

        await subscription.cancel();
        client.destroy();

        await expectLater(
          contextDoneCompleter.future.timeout(const Duration(seconds: 2)),
          completes,
        );
        await expectLater(
          generatorCancelledCompleter.future.timeout(
            const Duration(seconds: 2),
          ),
          completes,
        );
      },
    );

    test(
      'closes connection when handler returns response without consuming '
      'request body',
      () async {
        const requestHeaders =
            'POST /upload HTTP/1.1\r\n'
            'Host: localhost\r\n'
            'Content-Length: 100000\r\n'
            '\r\n';

        final text = await sendConnectionRequest(
          serverSocket,
          requestHeaders,
          handler: (Request request) async =>
              Response.bytes(stringToBytes('Unauthorized')),
        );

        expect(text, contains('Unauthorized'));
      },
    );

    test(
      'sends 100 Continue before body reading when Expect: 100-continue '
      'is requested',
      () async {
        serverSocket.listen((socket) {
          final connection = HttpConnection(
            socket,
            handler: (Request request) async {
              final body = await readStreamText(request);
              return Response.bytes(stringToBytes('echo: $body'));
            },
          );
          connection.start();
        });

        final client = await Socket.connect(
          InternetAddress.loopbackIPv4,
          serverSocket.port,
        );

        const requestHeaders =
            'POST /data HTTP/1.1\r\n'
            'Host: localhost\r\n'
            'Expect: 100-continue\r\n'
            'Content-Length: 11\r\n'
            '\r\n';

        client.add(stringToBytes(requestHeaders));

        final receivedChunks = <String>[];
        final completer = Completer<void>();

        client.cast<List<int>>().transform(utf8.decoder).listen(
          (data) {
            receivedChunks.add(data);
            if (data.contains('100 Continue')) {
              client.add(stringToBytes('hello world'));
            }
            if (data.contains('echo: hello world')) {
              completer.complete();
            }
          },
        );

        await completer.future.timeout(const Duration(seconds: 2));
        await client.close();

        final fullResponse = receivedChunks.join();
        expect(fullResponse, contains('HTTP/1.1 100 Continue\r\n\r\n'));
        expect(fullResponse, contains('echo: hello world'));
      },
    );

    test(
      'does not send 100 Continue when handler rejects request without '
      'reading body',
      () async {
        const requestHeaders =
            'POST /data HTTP/1.1\r\n'
            'Host: localhost\r\n'
            'Expect: 100-continue\r\n'
            'Content-Length: 1000\r\n'
            '\r\n';

        final text = await sendConnectionRequest(
          serverSocket,
          requestHeaders,
          handler: (Request request) async =>
              Response.bytes(stringToBytes('Unauthorized')),
        );

        expect(text, isNot(contains('100 Continue')));
        expect(text, contains('Unauthorized'));
      },
    );

    test(
      'returns 417 Expectation Failed for unknown Expect header',
      () async {
        const requestHeaders =
            'POST /data HTTP/1.1\r\n'
            'Host: localhost\r\n'
            'Expect: invalid-expectation\r\n'
            'Content-Length: 5\r\n'
            '\r\n';

        final text = await sendConnectionRequest(
          serverSocket,
          requestHeaders,
          handler: (Request request) async =>
              Response.bytes(stringToBytes('ok')),
        );

        expect(text, contains('417 Expectation Failed'));
      },
    );

    test(
      'readHeaderTimeout closes connection when header reading hangs',
      () async {
        serverSocket.listen((socket) {
          final connection = HttpConnection(
            socket,
            handler: (Request request) async =>
                Response.bytes(stringToBytes('ok')),
            readHeaderTimeout: const Duration(milliseconds: 50),
          );
          connection.start();
        });

        final client = await Socket.connect(
          InternetAddress.loopbackIPv4,
          serverSocket.port,
        );

        client.add(stringToBytes('GET /test HTTP/1.1\r\nHost: local'));

        final completer = Completer<void>();
        client.listen(
          (_) {},
          onDone: completer.complete,
          onError: (_) => completer.complete(),
        );

        await expectLater(
          completer.future.timeout(const Duration(milliseconds: 500)),
          completes,
        );
      },
    );

    test(
      'readBodyTimeout closes connection when body streaming hangs',
      () async {
        serverSocket.listen((socket) {
          final connection = HttpConnection(
            socket,
            handler: (Request request) async {
              await request.toList();
              return Response.bytes(stringToBytes('ok'));
            },
            readBodyTimeout: const Duration(milliseconds: 50),
          );
          connection.start();
        });

        final client = await Socket.connect(
          InternetAddress.loopbackIPv4,
          serverSocket.port,
        );

        client.add(
          stringToBytes(
            'POST /test HTTP/1.1\r\n'
            'Host: localhost\r\n'
            'Content-Length: 100\r\n'
            '\r\n'
            'partial body',
          ),
        );

        final completer = Completer<void>();
        client.listen(
          (_) {},
          onDone: completer.complete,
          onError: (_) => completer.complete(),
        );

        await expectLater(
          completer.future.timeout(const Duration(milliseconds: 500)),
          completes,
        );
      },
    );

    test(
      'idleTimeout closes Keep-Alive connection when idle after response',
      () async {
        serverSocket.listen((socket) {
          final connection = HttpConnection(
            socket,
            handler: (Request request) async =>
                Response.bytes(stringToBytes('ok')),
            idleTimeout: const Duration(milliseconds: 50),
          );
          connection.start();
        });

        final client = await Socket.connect(
          InternetAddress.loopbackIPv4,
          serverSocket.port,
        );

        client.add(stringToBytes('GET / HTTP/1.1\r\nHost: localhost\r\n\r\n'));

        final completer = Completer<void>();
        client.listen(
          (_) {},
          onDone: completer.complete,
          onError: (_) => completer.complete(),
        );

        await expectLater(
          completer.future.timeout(const Duration(milliseconds: 500)),
          completes,
        );
      },
    );

    test(
      'writeTimeout closes connection when writing response hangs',
      () async {
        serverSocket.listen((socket) {
          final connection = HttpConnection(
            socket,
            handler: (Request request) async {
              final controller = StreamController<Uint8List>();
              controller.add(stringToBytes('part1'));
              Timer(const Duration(milliseconds: 200), () {
                if (!controller.isClosed) {
                  controller.add(stringToBytes('part2'));
                  controller.close();
                }
              });
              return Response.stream(controller.stream);
            },
            writeTimeout: const Duration(milliseconds: 50),
          );
          connection.start();
        });

        final client = await Socket.connect(
          InternetAddress.loopbackIPv4,
          serverSocket.port,
        );

        client.add(stringToBytes('GET / HTTP/1.1\r\nHost: localhost\r\n\r\n'));

        final completer = Completer<void>();
        client.listen(
          (_) {},
          onDone: completer.complete,
          onError: (_) => completer.complete(),
        );

        await expectLater(
          completer.future.timeout(const Duration(milliseconds: 500)),
          completes,
        );
      },
    );

    test(
      'returns 505 HTTP Version Not Supported for unsupported version',
      () async {
        final resText = await sendConnectionRequest(
          serverSocket,
          'GET / HTTP/2.0\r\nHost: localhost\r\n\r\n',
          handler: (Request request) async => Response.text('OK'),
        );

        expect(resText, contains('505 HTTP Version Not Supported'));
      },
    );

    test(
      'returns 501 Not Implemented for unsupported Transfer-Encoding',
      () async {
        final resText = await sendConnectionRequest(
          serverSocket,
          'POST / HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: gzip\r\n\r\n',
          handler: (Request request) async => Response.text('OK'),
        );

        expect(resText, contains('501 Not Implemented'));
      },
    );

    test(
      'returns 405 Method Not Allowed for TRACE and CONNECT methods',
      () async {
        final resText = await sendConnectionRequest(
          serverSocket,
          'TRACE / HTTP/1.1\r\nHost: localhost\r\n\r\n',
          handler: (Request request) async => Response.text('OK'),
        );

        expect(resText, contains('405 Method Not Allowed'));
      },
    );

    test('sends 100 Continue for Expect: 100-continue header', () async {
      serverSocket.listen((socket) {
        final connection = HttpConnection(
          socket,
          handler: (Request request) async {
            final body = await request.text();
            return Response.text('Received: $body');
          },
        );
        connection.start();
      });

      final client = await Socket.connect(
        InternetAddress.loopbackIPv4,
        serverSocket.port,
      );

      client.add(
        stringToBytes(
          'POST /upload HTTP/1.1\r\n'
          'Host: localhost\r\n'
          'Connection: close\r\n'
          'Expect: 100-continue\r\n'
          'Content-Length: 5\r\n\r\n',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      client.add(stringToBytes('hello'));

      final responseBytes = <int>[];
      await client.forEach(responseBytes.addAll);
      await client.close();

      final resText = bytesToString(Uint8List.fromList(responseBytes));
      expect(resText, contains('100 Continue'));
      expect(resText, contains('Received: hello'));
    });

    test(
      'returns 400 Bad Request for conflicting Content-Length headers',
      () async {
        final resText = await sendConnectionRequest(
          serverSocket,
          'POST / HTTP/1.1\r\n'
          'Host: localhost\r\n'
          'Content-Length: 5\r\n'
          'Content-Length: 10\r\n\r\n',
          handler: (Request request) async => Response.text('OK'),
        );

        expect(resText, contains('400 Bad Request'));
      },
    );

    test(
      'returns 500 Internal Server Error when handler throws before response',
      () async {
        final resText = await sendConnectionRequest(
          serverSocket,
          'GET / HTTP/1.1\r\nHost: localhost\r\n\r\n',
          handler: (Request request) async {
            throw StateError('Handler crash before response');
          },
        );

        expect(resText, contains('500 Internal Server Error'));
      },
    );

    test(
      'returns 400 Bad Request for OPTIONS request containing body',
      () async {
        final resText = await sendConnectionRequest(
          serverSocket,
          'OPTIONS / HTTP/1.1\r\n'
          'Host: localhost\r\n'
          'Content-Length: 5\r\n\r\n'
          'hello',
          handler: (Request request) async => Response.text('OK'),
        );

        expect(resText, contains('400 Bad Request'));
      },
    );

    test('returns 400 Bad Request when URI format is invalid', () async {
      final resText = await sendConnectionRequest(
        serverSocket,
        'GET http://[invalid-ipv6-host/ HTTP/1.1\r\n'
        'Host: localhost\r\n\r\n',
        handler: (Request request) async => Response.text('OK'),
      );

      expect(resText, contains('400 Bad Request'));
    });

    test(
      'flushes socket when unflushedBytes exceeds flush threshold',
      () async {
        final largePayload = 'A' * (70 * 1024);
        serverSocket.listen((socket) {
          final connection = HttpConnection(
            socket,
            handler: (Request request) async => Response.text(largePayload),
          );
          connection.start();
        });

        final client = await Socket.connect(
          InternetAddress.loopbackIPv4,
          serverSocket.port,
        );

        client.add(
          stringToBytes(
            'GET / HTTP/1.1\r\n'
            'Host: localhost\r\n'
            'Connection: keep-alive\r\n\r\n',
          ),
        );

        final responseBytes = <int>[];
        await for (final chunk in client) {
          responseBytes.addAll(chunk);
          if (responseBytes.length >= largePayload.length) {
            unawaited(client.close());
            break;
          }
        }

        final resText = bytesToString(Uint8List.fromList(responseBytes));
        expect(resText, contains('200 OK'));
        expect(resText, contains(largePayload));
      },
    );

    test('ConnectionInfo.toString returns formatted ip and ports', () {
      final info = ConnectionInfo(
        remoteAddress: InternetAddress.loopbackIPv4,
        remotePort: 12345,
        localPort: 8080,
      );

      expect(info.toString(), contains('12345 -> :8080'));
      expect(info.toString(), contains('127.0.0.1'));
    });

    test(
      'logs debug/error messages when logger is provided and errors occur',
      () async {
        final logHandler = MockLogHandler();
        when(() => logHandler.enabled(any(), any())).thenReturn(true);

        final logger = Logger(handler: logHandler);

        serverSocket.listen((socket) {
          final connection = HttpConnection(
            socket,
            logger: logger,
            handler: (Request request) async {
              if (request.uri.path == '/crash') {
                throw StateError('Handler crashed');
              }
              return Response.text('OK');
            },
          );
          connection.start();
        });

        // 1. Trigger parser exception log
        final client1 = await Socket.connect(
          InternetAddress.loopbackIPv4,
          serverSocket.port,
        );
        client1.add(stringToBytes('INVALID METHOD HEADER\r\n\r\n'));
        await client1.forEach((_) {});
        await client1.close();

        // 2. Trigger handler exception log
        final client2 = await Socket.connect(
          InternetAddress.loopbackIPv4,
          serverSocket.port,
        );
        client2.add(
          stringToBytes('GET /crash HTTP/1.1\r\nHost: localhost\r\n\r\n'),
        );
        await client2.forEach((_) {});
        await client2.close();

        verify(
          () => logHandler.handle(any(), any()),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    test(
      'pauses subscription when pipelined request arrives before handler '
      'completes',
      () async {
        final handlerCompleter = Completer<void>();

        serverSocket.listen((socket) {
          final connection = HttpConnection(
            socket,
            handler: (Request request) async {
              if (request.uri.path == '/first') {
                await handlerCompleter.future;
                return Response.text('First Done');
              }
              return Response.text('Second Done');
            },
          );
          connection.start();
        });

        final client = await Socket.connect(
          InternetAddress.loopbackIPv4,
          serverSocket.port,
        );

        // Send both requests pipelined together in one byte array
        client.add(
          stringToBytes(
            'GET /first HTTP/1.1\r\n'
            'Host: localhost\r\n'
            'Connection: keep-alive\r\n\r\n'
            'GET /second HTTP/1.1\r\n'
            'Host: localhost\r\n'
            'Connection: close\r\n\r\n',
          ),
        );

        // Allow microtask to process first request head and enter pause state
        await Future<void>.delayed(const Duration(milliseconds: 50));
        handlerCompleter.complete();

        final responseBytes = <int>[];
        await client.forEach(responseBytes.addAll);
        await client.close();

        final resText = bytesToString(Uint8List.fromList(responseBytes));
        expect(resText, contains('First Done'));
        expect(resText, contains('Second Done'));
      },
    );
  });
}

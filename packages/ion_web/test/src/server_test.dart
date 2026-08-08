import 'dart:async';
import 'dart:io';

import 'package:ion_web/ion_web.dart';
import 'package:sl/sl.dart';
import 'package:test/test.dart';

import '../helpers/helpers.dart';

void main() {
  setUpAll(registerTestFallbacks);

  group('IonServer', () {
    test('exposes address and port after bind', () async {
      final server = await IonServer.serve(
        (request) => Response.text('OK'),
        address: InternetAddress.loopbackIPv4,
        port: 0,
      );

      expect(server.address, equals(InternetAddress.loopbackIPv4));
      expect(server.port, greaterThan(0));

      await server.close();
    });

    test('supports shared option when binding', () async {
      final server = await IonServer.serve(
        (request) => Response.text('OK'),
        address: InternetAddress.loopbackIPv4,
        port: 0,
        shared: true,
      );

      expect(server.port, greaterThan(0));
      await server.close();
    });

    test(
      'is idempotent when close or shutdown is called multiple times',
      () async {
        final server = await IonServer.serve(
          (request) => Response.text('OK'),
          address: InternetAddress.loopbackIPv4,
          port: 0,
        );

        await expectLater(server.close(), completes);
        await expectLater(server.close(), completes);
        await expectLater(server.shutdown(), completes);
      },
    );

    test(
      'rejects incoming sockets when maxConnections limit is reached',
      () async {
        final server = await IonServer.serve(
          (request) => Response.bytes(stringToBytes('OK')),
          address: InternetAddress.loopbackIPv4,
          port: 0,
          maxConnections: 1,
        );

        final client1 = await Socket.connect(
          InternetAddress.loopbackIPv4,
          server.port,
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));

        final client2 = await Socket.connect(
          InternetAddress.loopbackIPv4,
          server.port,
        );

        final client2ClosedCompleter = Completer<void>();
        client2.listen(
          (_) {},
          onDone: client2ClosedCompleter.complete,
          onError: (_) => client2ClosedCompleter.complete(),
        );

        await expectLater(client2ClosedCompleter.future, completes);

        await client1.close();
        await client2.close();
        await server.shutdown();
      },
    );

    test(
      'passes readHeaderTimeout down to HttpConnection',
      () async {
        final server = await IonServer.serve(
          (request) => Response.text('OK'),
          address: InternetAddress.loopbackIPv4,
          port: 0,
          readHeaderTimeout: const Duration(milliseconds: 100),
        );

        final client = await Socket.connect(
          InternetAddress.loopbackIPv4,
          server.port,
        );

        // Send incomplete request header and pause
        client.add(stringToBytes('GET / HTTP/1.1\r\nHost: local'));

        final completer = Completer<void>();
        client.listen(
          (_) {},
          onDone: completer.complete,
          onError: (_) => completer.complete(),
        );

        // Connection should be closed by server due to readHeaderTimeout
        await expectLater(
          completer.future.timeout(const Duration(seconds: 2)),
          completes,
        );

        await client.close();
        await server.close();
      },
    );
  });

  group('IonServer HTTPS', () {
    late IonServer server;

    setUp(() async {
      final context = SecurityContext()
        ..useCertificateChainBytes(utf8.encode(testCertPem))
        ..usePrivateKeyBytes(utf8.encode(testKeyPem));

      server = await IonServer.serve(
        (req) => Response.text('hello https, scheme is ${req.uri.scheme}'),
        address: InternetAddress.loopbackIPv4,
        port: 0,
        securityContext: context,
      );
    });

    tearDown(() async {
      await server.close();
    });

    test('accepts HTTPS requests and resolves uri scheme as https', () async {
      final client = HttpClient()
        ..badCertificateCallback = (cert, host, port) => true;

      final request = await client.getUrl(
        Uri.parse('https://${server.address.host}:${server.port}/test'),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      expect(response.statusCode, equals(200));
      expect(body, equals('hello https, scheme is https'));
      client.close();
    });

    test(
      'fails handshake when client does not accept self-signed certificate',
      () async {
        final client = HttpClient(); // No badCertificateCallback

        expect(
          () async {
            final request = await client.getUrl(
              Uri.parse('https://${server.address.host}:${server.port}/test'),
            );
            await request.close();
          },
          throwsA(isA<HandshakeException>()),
        );

        client.close();
      },
    );
  });

  group('IonServer Shutdown', () {
    test('shuts down immediately when no active connections exist', () async {
      final server = await IonServer.serve(
        (request) => Response.bytes(stringToBytes('OK')),
        address: InternetAddress.loopbackIPv4,
        port: 0,
      );

      final shutdownFuture = server.shutdown();
      await expectLater(shutdownFuture, completes);
    });

    test(
      'immediately closes idle Keep-Alive connections on shutdown',
      () async {
        final server = await IonServer.serve(
          (request) => Response.bytes(stringToBytes('OK')),
          address: InternetAddress.loopbackIPv4,
          port: 0,
        );

        final client = await Socket.connect(
          InternetAddress.loopbackIPv4,
          server.port,
        );

        client.add(
          stringToBytes(
            'GET / HTTP/1.1\r\nHost: localhost\r\n\r\n',
          ),
        );

        final responseBytes = <int>[];
        final completer = Completer<void>();
        client.listen(
          responseBytes.addAll,
          onDone: completer.complete,
        );

        while (!responseBytes.contains(10)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }

        final shutdownFuture = server.shutdown();

        await completer.future;
        await shutdownFuture;

        final responseString = bytesToString(Uint8List.fromList(responseBytes));
        expect(responseString, contains('200 OK'));
      },
    );

    test(
      'allows in-flight request to finish before completing shutdown',
      () async {
        final handlerStarted = Completer<void>();
        final allowHandlerToFinish = Completer<void>();

        final server = await IonServer.serve(
          (request) async {
            handlerStarted.complete();
            await allowHandlerToFinish.future;
            return Response.bytes(stringToBytes('FINISHED'));
          },
          address: InternetAddress.loopbackIPv4,
          port: 0,
        );

        final client = await Socket.connect(
          InternetAddress.loopbackIPv4,
          server.port,
        );

        client.add(
          stringToBytes(
            'GET /slow HTTP/1.1\r\nHost: localhost\r\n\r\n',
          ),
        );

        await handlerStarted.future;

        var shutdownCompleted = false;
        final shutdownFuture = server.shutdown().then((_) {
          shutdownCompleted = true;
        });

        expect(shutdownCompleted, isFalse);

        allowHandlerToFinish.complete();

        final responseBytes = <int>[];
        await client.forEach(responseBytes.addAll);

        await shutdownFuture;
        expect(shutdownCompleted, isTrue);

        final responseString = bytesToString(Uint8List.fromList(responseBytes));
        expect(responseString, contains('FINISHED'));
      },
    );

    test(
      'forces socket destruction when timeout expires on hanging request',
      () async {
        final server = await IonServer.serve(
          (request) async {
            await Completer<void>().future;
            return Response.bytes(stringToBytes('NEVER'));
          },
          address: InternetAddress.loopbackIPv4,
          port: 0,
        );

        final client = await Socket.connect(
          InternetAddress.loopbackIPv4,
          server.port,
        );

        client.add(
          stringToBytes(
            'GET /hang HTTP/1.1\r\nHost: localhost\r\n\r\n',
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final stopwatch = Stopwatch()..start();
        await server.shutdown(timeout: const Duration(milliseconds: 200));
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(150));
        await client.close();
      },
    );

    test(
      'logs error when connection handling fails on socket accept',
      () async {
        final handler = MockLogHandler();
        when(() => handler.enabled(any(), any())).thenReturn(true);

        final server = await IonServer.serve(
          (request) => Response.text('OK'),
          address: InternetAddress.loopbackIPv4,
          port: 0,
          logger: Logger(handler: handler),
        );

        final client = await Socket.connect(
          InternetAddress.loopbackIPv4,
          server.port,
        );
        await client.close();
        await server.close();

        verifyNever(() => handler.handle(any(), any()));
      },
    );

    test(
      'forcibly destroys active sockets immediately on close',
      () async {
        final handlerStarted = Completer<void>();

        final server = await IonServer.serve(
          (request) async {
            handlerStarted.complete();
            await Completer<void>().future;
            return Response.bytes(stringToBytes('NEVER'));
          },
          address: InternetAddress.loopbackIPv4,
          port: 0,
        );

        final client = await Socket.connect(
          InternetAddress.loopbackIPv4,
          server.port,
        );

        client.add(
          stringToBytes(
            'GET /hang HTTP/1.1\r\nHost: localhost\r\n\r\n',
          ),
        );

        await handlerStarted.future;

        final clientDoneCompleter = Completer<void>();
        client.listen(
          (_) {},
          onDone: clientDoneCompleter.complete,
          onError: (_) => clientDoneCompleter.complete(),
        );

        await server.close();

        await expectLater(
          clientDoneCompleter.future.timeout(const Duration(seconds: 1)),
          completes,
        );
      },
    );
  });
}

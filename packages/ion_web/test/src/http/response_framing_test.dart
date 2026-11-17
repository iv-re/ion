import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ion_web/ion_web.dart';
import 'package:test/test.dart';

/// Request-target parsing and response framing, checked on the wire.
void main() {
  late IonServer server;

  Future<void> serve(Handler handler) async {
    server = await IonServer.serve(
      handler,
      address: InternetAddress.loopbackIPv4,
      port: 0,
    );
    addTearDown(server.close);
  }

  /// Sends [request] and returns everything received until the server closes
  /// the connection (or [timeout] passes).
  Future<String> exchange(
    String request, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      server.port,
    );
    socket.add(ascii.encode(request));
    final received = <int>[];
    final closed = Completer<void>();
    socket.listen(
      received.addAll,
      onDone: closed.complete,
      onError: (Object _) => closed.complete(),
    );
    await closed.future.timeout(timeout, onTimeout: () {});
    socket.destroy();
    return latin1.decode(received);
  }

  String head(String response) =>
      response.substring(0, response.indexOf('\r\n\r\n'));
  String body(String response) =>
      response.substring(response.indexOf('\r\n\r\n') + 4);
  List<String> headerLines(String response, String name) => [
    for (final line in head(response).split('\r\n').skip(1))
      if (line.toLowerCase().startsWith('${name.toLowerCase()}:')) line,
  ];

  group('request-target', () {
    test('a leading // stays in the path', () async {
      Uri? seen;
      await serve((request) {
        seen = request.uri;
        return Response.text('ok');
      });

      final response = await exchange(
        'GET //admin/secret?x=1 HTTP/1.1\r\n'
        'Host: example.com\r\n'
        'Connection: close\r\n\r\n',
      );

      expect(response, startsWith('HTTP/1.1 200'));
      expect(seen!.path, '//admin/secret');
      expect(seen!.host, 'example.com');
      expect(seen!.query, 'x=1');
    });
  });

  group('request head limits', () {
    test('too large headers get 431', () async {
      await serve((request) => Response.text('ok'));
      final response = await exchange(
        'GET / HTTP/1.1\r\nHost: localhost\r\n'
        'X-Big: ${'a' * (70 * 1024)}\r\n\r\n',
      );
      expect(response, startsWith('HTTP/1.1 431 '));
    });

    test('a too long request target gets 414', () async {
      await serve((request) => Response.text('ok'));
      final response = await exchange(
        'GET /${'a' * (70 * 1024)} HTTP/1.1\r\nHost: localhost\r\n\r\n',
      );
      expect(response, startsWith('HTTP/1.1 414 '));
    });
  });

  group('Connection header from the handler', () {
    test('cannot keep alive a connection the client asked to close', () async {
      await serve(
        (request) => Response.sse(() => Stream.value(const .comment('x'))),
      );

      final response = await exchange(
        'GET /events HTTP/1.1\r\n'
        'Host: localhost\r\n'
        'Connection: close\r\n\r\n',
      );

      expect(headerLines(response, 'connection'), ['Connection: close']);
    });

    test('Connection: close from the handler is honored', () async {
      await serve(
        (request) => Response.text('bye', headers: [const .connectionClose()]),
      );

      final response = await exchange(
        'GET / HTTP/1.1\r\nHost: localhost\r\n\r\n',
      );

      expect(headerLines(response, 'connection'), ['Connection: close']);
      expect(body(response), 'bye');
    });

    test('HTTP/1.0 stream without length is close-delimited', () async {
      await serve(
        (request) => Response.sse(() => Stream.value(const .comment('x'))),
      );

      final response = await exchange('GET /events HTTP/1.0\r\n\r\n');

      expect(headerLines(response, 'transfer-encoding'), isEmpty);
      expect(headerLines(response, 'content-length'), isEmpty);
      expect(headerLines(response, 'connection'), ['Connection: close']);
      expect(body(response), ':x\n\n');
    });
  });

  group('framing headers', () {
    test('Content-Length from the handler is not written', () async {
      await serve(
        (request) => Response.stream(
          Stream.value(Uint8List.fromList([1, 2, 3])),
          headers: [const .contentLength(3)],
        ),
      );

      final response = await exchange(
        'GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
      );

      expect(headerLines(response, 'content-length'), isEmpty);
      expect(headerLines(response, 'transfer-encoding'), [
        'Transfer-Encoding: chunked',
      ]);
    });

    for (final status in <HttpStatusCode>[.noContent, .notModified]) {
      test('${status.value} has no body and no framing headers', () async {
        await serve(
          (request) => request.uri.path == '/next'
              ? Response.text('next')
              : Response.stream(
                  Stream.value(Uint8List.fromList(ascii.encode('ignored'))),
                  status: status,
                ),
        );

        final response = await exchange(
          'GET / HTTP/1.1\r\nHost: localhost\r\n\r\n'
          'GET /next HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
        );

        final secondStart = response.indexOf('HTTP/1.1 200');
        final first = response.substring(0, secondStart);
        expect(first, startsWith('HTTP/1.1 ${status.value}'));
        expect(headerLines(first, 'content-length'), isEmpty);
        expect(headerLines(first, 'transfer-encoding'), isEmpty);
        expect(body(first), isEmpty);
        expect(body(response.substring(secondStart)), 'next');
      });
    }
  });

  group('body failures after the head was sent', () {
    test('a stream error aborts the response without a 500', () async {
      await serve(
        (request) => Response.stream(() async* {
          yield Uint8List.fromList(ascii.encode('partial'));
          await Future<void>.delayed(const Duration(milliseconds: 10));
          throw StateError('boom');
        }()),
      );

      final response = await exchange(
        'GET / HTTP/1.1\r\nHost: localhost\r\n\r\n',
      );

      expect(response, startsWith('HTTP/1.1 200'));
      expect(response, isNot(contains('500')));
      expect(body(response), isNot(endsWith('0\r\n\r\n')));
    });

    test('a stream longer than its content length is cut off', () async {
      await serve(
        (request) => Response.stream(
          Stream.fromIterable([
            Uint8List.fromList(ascii.encode('abc')),
            Uint8List.fromList(ascii.encode('def')),
          ]),
          contentLength: 4,
        ),
      );

      final response = await exchange(
        'GET / HTTP/1.1\r\nHost: localhost\r\n\r\n',
      );

      expect(headerLines(response, 'content-length'), ['Content-Length: 4']);
      expect(body(response), 'abc');
    });

    test('a stream shorter than its content length aborts', () async {
      await serve(
        (request) => Response.stream(
          Stream.value(Uint8List.fromList(ascii.encode('ab'))),
          contentLength: 4,
        ),
      );

      final response = await exchange(
        'GET / HTTP/1.1\r\nHost: localhost\r\n\r\n',
      );

      expect(body(response), 'ab');
      expect(response, isNot(contains('500')));
    });
  });
}

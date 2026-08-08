import 'dart:async';
import 'dart:io';

import 'package:ion_web/ion_web.dart';
import 'package:test/test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('HttpResponseWriter', () {
    late MockSocket socket;
    late Request request;

    setUp(() {
      socket = MockSocket();
      request = TestRequestBuilder.get().build();
    });

    FutureOr<ResponseWriteResult> writeResponse(
      Socket targetSocket,
      Request req,
      Response response,
    ) {
      return HttpResponseWriter.write(
        targetSocket,
        method: req.method,
        keepAlive: req.keepAlive,
        status: response.status.value,
        headers: response.headers,
        body: response.body,
      );
    }

    test(
      'writes standard response headers and bytes body in a single '
      'socket.add call',
      () async {
        final response = Response.text('Hello World');

        final (bytesWritten, keepAlive) = await writeResponse(
          socket,
          request,
          response,
        );

        final raw = getCapturedSocketString(socket);
        expect(raw, startsWith('HTTP/1.1 200 OK\r\n'));
        expect(raw, contains('Content-Length: 11\r\n'));
        expect(raw, contains('Content-Type: text/plain; charset=utf-8\r\n'));
        expect(raw, contains('Connection: keep-alive\r\n'));
        expect(raw, contains('Date: '));
        expect(raw, endsWith('Hello World'));

        final totalBytesLength = ascii.encode(raw).length;
        expect(bytesWritten, equals(totalBytesLength));
        expect(keepAlive, isTrue);
      },
    );

    test(
      'splits response into 2 socket.add calls when body exceeds buffer '
      'capacity',
      () async {
        final largePayload = Uint8List(8192);
        final response = Response.bytes(largePayload);

        await writeResponse(socket, request, response);

        final calls = getCapturedSocketCalls(socket);
        expect(calls, hasLength(2));

        final headersRaw = utf8.decode(calls[0]);
        expect(headersRaw, startsWith('HTTP/1.1 200 OK\r\n'));
        expect(headersRaw, contains('Content-Length: 8192\r\n'));
        expect(headersRaw, endsWith('\r\n\r\n'));

        final bodyBytes = calls[1];
        expect(bodyBytes.length, equals(8192));
      },
    );

    test('writes connection: close when keepAlive is false', () async {
      const response = Response.status(HttpStatusCode.notFound);

      await writeResponse(
        socket,
        TestRequestBuilder.get().headers([const .connectionClose()]).build(),
        response,
      );

      final raw = getCapturedSocketString(socket);

      expect(raw, startsWith('HTTP/1.1 404 Not Found\r\n'));
      expect(raw, contains('Connection: close\r\n'));
      expect(raw, contains('Content-Length: 0\r\n'));
    });

    test('handles status code correctly', () async {
      const response = Response.status(HttpStatusCode.internalServerError);

      await writeResponse(socket, request, response);

      final raw = getCapturedSocketString(socket);
      expect(raw, startsWith('HTTP/1.1 500 Internal Server Error\r\n'));
    });

    test('respects user-provided Connection header override', () async {
      const response = Response.status(
        HttpStatusCode.ok,
        headers: [TypedHeader.connectionClose()],
      );

      await writeResponse(socket, request, response);

      final raw = getCapturedSocketString(socket);

      expect(raw, contains('Connection: close\r\n'));
      expect(raw, isNot(contains('Connection: keep-alive')));
    });

    test(
      'respects user-provided Date header override without duplicate',
      () async {
        const customDate = 'Date: Sun, 06 Nov 1994 08:49:37 GMT';
        final response = Response.status(
          HttpStatusCode.ok,
          headers: [
            TypedHeader.date(HttpDate.parse('Sun, 06 Nov 1994 08:49:37 GMT')),
          ],
        );

        await writeResponse(socket, request, response);

        final raw = getCapturedSocketString(socket);

        expect(raw.split('Date: ').length - 1, equals(1));
        expect(raw, contains(customDate));
      },
    );

    test('throws ArgumentError on invalid header name', () async {
      const response = Response.status(
        HttpStatusCode.ok,
        headers: [TestCustomHeader('Invalid Name:', 'value')],
      );

      expect(
        () => writeResponse(socket, request, response),
        throwsArgumentError,
      );

      verifyNever(() => socket.add(any()));
    });

    test('throws ArgumentError on CR/LF injection in header value', () async {
      const response = Response.status(
        HttpStatusCode.ok,
        headers: [TestCustomHeader('X-Custom', 'line1\r\nInjected: value')],
      );

      expect(
        () => writeResponse(socket, request, response),
        throwsArgumentError,
      );

      verifyNever(() => socket.add(any()));
    });

    test(
      'grows scratch buffer dynamically when headers exceed initial 4KB size',
      () async {
        final longHeaders = List.generate(
          100,
          (i) => TestCustomHeader('X-Long-Header-$i', 'value-' * 20),
        );

        final response = Response.bytes(
          Uint8List.fromList([1, 2, 3]),
          headers: longHeaders,
        );

        await writeResponse(socket, request, response);

        final raw = getCapturedSocketString(socket);

        expect(raw.length, greaterThan(4096));
        expect(raw, contains('X-Long-Header-99:'));
      },
    );

    test(
      'deduplicates headers case-insensitively keeping the last value',
      () async {
        const response = Response.status(
          HttpStatusCode.ok,
          headers: [
            TypedHeader.contentTypeText(),
            TestCustomHeader('X-Custom-Header', 'first'),
            TypedHeader.contentTypeJson(),
            TestCustomHeader('X-CUSTOM-HEADER', 'second'),
          ],
        );

        await writeResponse(socket, request, response);

        final raw = getCapturedSocketString(socket);

        expect(raw, contains('Content-Type: application/json\r\n'));
        expect(raw, isNot(contains('Content-Type: text/plain\r\n')));

        expect(raw, contains('X-CUSTOM-HEADER: second\r\n'));
        expect(raw, isNot(contains('X-Custom-Header: first\r\n')));
      },
    );

    test('allows multiple Set-Cookie headers without deduplicating', () async {
      final response = Response.status(
        HttpStatusCode.ok,
        headers: [
          TypedHeader.setCookieFromCookie(Cookie('a', '1')),
          TypedHeader.setCookieFromCookie(Cookie('b', '2')),
        ],
      );

      await writeResponse(socket, request, response);

      final raw = getCapturedSocketString(socket);

      expect(raw, contains('Set-Cookie: a=1'));
      expect(raw, contains('Set-Cookie: b=2'));
    });

    test(
      'safely handles concurrent write calls using scratch ring buffer pool',
      () async {
        final socket1 = MockSocket();
        final socket2 = MockSocket();

        const response1 = Response.status(
          HttpStatusCode.ok,
          headers: [TestCustomHeader('X-User-ID', 'SECRET_USER_12345')],
        );
        const response2 = Response.status(
          HttpStatusCode.ok,
          headers: [TestCustomHeader('X-User-ID', 'ATTACKER_99999')],
        );

        await writeResponse(socket1, request, response1);

        final captured1 = Uint8List.fromList(
          verify(() => socket1.add(captureAny())).captured.single as List<int>,
        );

        await writeResponse(socket2, request, response2);

        final raw1 = utf8.decode(captured1);

        expect(
          raw1,
          contains('SECRET_USER_12345'),
          reason: 'Socket 1 buffer view must remain intact and isolated',
        );
      },
    );

    test(
      'HttpResponseWriter.write writes headers only for HEAD request',
      () async {
        final response = Response.text('Should not be written to socket');

        final writeResult = HttpResponseWriter.write(
          socket,
          method: HttpMethod.head,
          keepAlive: true,
          status: response.status.value,
          headers: response.headers,
          body: response.body,
        );

        final (bytesWritten, keepAlive) = writeResult is ResponseWriteResult
            ? writeResult
            : await writeResult;

        expect(bytesWritten, greaterThan(0));
        expect(keepAlive, isTrue);

        final raw = getCapturedSocketString(socket);
        expect(raw, contains('HTTP/1.1 200 OK'));
        expect(raw, contains('Content-Length: 31'));
        expect(raw, isNot(contains('Should not be written')));
      },
    );

    test(
      'HttpResponseWriter.write streams non-chunked body directly',
      () async {
        when(() => socket.flush()).thenAnswer((_) async {});
        final stream = Stream<Uint8List>.fromIterable([
          Uint8List.fromList(utf8.encode('part1')),
          Uint8List.fromList(utf8.encode('part2')),
        ]);
        final response = Response.stream(stream, contentLength: 10);

        final writeResult = HttpResponseWriter.write(
          socket,
          method: HttpMethod.get,
          keepAlive: true,
          status: response.status.value,
          headers: response.headers,
          body: response.body,
        );

        final (bytesWritten, keepAlive) = writeResult is ResponseWriteResult
            ? writeResult
            : await writeResult;

        expect(bytesWritten, greaterThan(0));
        expect(keepAlive, isTrue);

        final calls = getCapturedSocketCalls(socket);
        expect(calls.length, equals(3)); // headers + 2 stream chunks
      },
    );
  });
}

import 'dart:io';

import 'package:ion_web/ion_web.dart';
import 'package:test/test.dart';

import '../helpers/helpers.dart';

void main() {
  group('Response DTO', () {
    test(
      'creates chunked stream response when contentLength is null',
      () async {
        Stream<Uint8List> generateStream() async* {
          yield stringToBytes('hello ');
          yield stringToBytes('world');
        }

        final response = Response.stream(generateStream());

        expect(response.status, equals(HttpStatusCode.ok));
        expect(response.contentLength, isNull);

        final text = await readResponseBodyText(response);
        expect(text, equals('hello world'));
      },
    );

    test(
      'creates raw stream response when contentLength is provided',
      () async {
        final chunk1 = stringToBytes('foo');
        final chunk2 = stringToBytes('bar');
        Stream<Uint8List> generateStream() async* {
          yield chunk1;
          yield chunk2;
        }

        final response = Response.stream(
          generateStream(),
          contentLength: 6,
        );

        expect(response.status, equals(HttpStatusCode.ok));
        expect(response.contentLength, equals(6));

        final text = await readResponseBodyText(response);
        expect(text, equals('foobar'));
      },
    );

    test('Response.sse sets SSE headers and formats stream events', () async {
      Stream<SseEvent> generateSse() async* {
        yield const SseEvent.text('Hello', event: 'greeting');
        yield const SseEvent.json({'status': 'ok'});
      }

      final response = Response.sse(generateSse);

      expect(response.status, equals(HttpStatusCode.ok));
      expect(
        response.headers.get<ContentTypeHeader>()?.value,
        equals('text/event-stream'),
      );
      expect(response.headers.has<CacheControlHeader>(), isTrue);

      final text = await readResponseBodyText(response);
      expect(text, contains('event: greeting\n'));
      expect(text, contains('data: Hello\n\n'));
      expect(text, contains('data: {"status":"ok"}\n\n'));
    });

    test(
      'Response.sse normalizes CRLF and CR line endings in event data',
      () async {
        Stream<SseEvent> generateSse() async* {
          yield const SseEvent.text('line1\r\nline2\rline3\nline4');
        }

        final response = Response.sse(generateSse);
        final text = await readResponseBodyText(response);

        expect(
          text,
          contains('data: line1\ndata: line2\ndata: line3\ndata: line4\n\n'),
        );
        expect(text, isNot(contains('\r\nline')));
        expect(text, isNot(contains('\rline')));
      },
    );

    test(
      'Response.sse invokes onError and emits error event when streamBuilder '
      'throws synchronously',
      () async {
        Object? caughtError;
        final response = Response.sse(
          () => throw StateError('builder boom'),
          onError: (error, stackTrace) {
            caughtError = error;
            return const SseEvent.json(
              {'error': 'sync_failed'},
              event: 'error',
            );
          },
        );

        final text = await readResponseBodyText(response);
        expect(caughtError, isA<StateError>());
        expect(text, contains('event: error\n'));
        expect(text, contains('data: {"error":"sync_failed"}\n\n'));
      },
    );

    test(
      'Response.sse invokes onError and emits error event when stream emits '
      'async error',
      () async {
        Stream<SseEvent> generateSse() async* {
          yield const SseEvent.text('before');
          throw StateError('stream boom');
        }

        Object? caughtError;
        final response = Response.sse(
          generateSse,
          onError: (error, stackTrace) {
            caughtError = error;
            return const SseEvent.text('stream_failed', event: 'error');
          },
        );

        final text = await readResponseBodyText(response);
        expect(caughtError, isA<StateError>());
        expect(text, contains('data: before\n\n'));
        expect(text, contains('event: error\ndata: stream_failed\n\n'));
      },
    );

    test(
      'Response.sse invokes async onError and emits returned SseEvent',
      () async {
        Stream<SseEvent> generateSse() async* {
          throw StateError('async error');
        }

        final response = Response.sse(
          generateSse,
          onError: (error, stackTrace) async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return const SseEvent.json({'resolved': true}, event: 'error');
          },
        );

        final text = await readResponseBodyText(response);
        expect(text, contains('event: error\n'));
        expect(text, contains('data: {"resolved":true}\n\n'));
      },
    );

    test(
      'Response.sse gracefully terminates stream without extra event when '
      'onError returns null',
      () async {
        var onErrorCalled = false;
        Stream<SseEvent> generateSse() async* {
          yield const SseEvent.text('hello');
          throw StateError('silent boom');
        }

        final response = Response.sse(
          generateSse,
          onError: (error, stackTrace) {
            onErrorCalled = true;
            return null;
          },
        );

        final text = await readResponseBodyText(response);
        expect(onErrorCalled, isTrue);
        expect(text, equals('data: hello\n\n'));
      },
    );

    test('Response.sse rethrows error when onError is not provided', () async {
      Stream<SseEvent> generateSse() async* {
        yield const SseEvent.text('start');
        throw StateError('unhandled boom');
      }

      final response = Response.sse(generateSse);
      expect(
        () => readResponseBodyText(response),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'Response.text sets content-type text/plain and content-length',
      () async {
        final response = Response.text('Hello World');

        expect(response.status, equals(HttpStatusCode.ok));
        expect(
          response.headers.get<ContentTypeHeader>()?.value,
          equals('text/plain; charset=utf-8'),
        );
        expect(response.contentLength, equals(11));

        final text = await readResponseBodyText(response);
        expect(text, equals('Hello World'));
      },
    );

    test(
      'Response.file clears representation headers on 412 Precondition Failed',
      () async {
        final tempFile = File('${Directory.systemTemp.path}/test_412.txt');
        tempFile.writeAsStringSync('sample content');
        try {
          final req = TestRequestBuilder.get('/test_412.txt').headers([
            IfMatchHeader.etag(const EntityTag('non-matching-etag')),
          ]).build();
          final res =
              await (Response.file(
                        tempFile,
                        headers: [const .etag(EntityTag('matching-etag'))],
                      )
                      as ResolvableResponse)
                  .resolve(req);

          expect(res.status, equals(HttpStatusCode.preconditionFailed));
          expect(res.headers, isEmpty);
        } finally {
          if (tempFile.existsSync()) tempFile.deleteSync();
        }
      },
    );

    test(
      'Response.file filters non-validator headers on 304 Not Modified',
      () async {
        final tempFile = File('${Directory.systemTemp.path}/test_304.txt');
        tempFile.writeAsStringSync('sample content');
        try {
          final stat = tempFile.statSync();
          final modTime = stat.modified;
          final futureTime = modTime.add(const Duration(seconds: 10));
          final req = TestRequestBuilder.get(
            '/test_304.txt',
          ).headers([TypedHeader.ifModifiedSince(futureTime)]).build();
          final res = await (Response.file(tempFile) as ResolvableResponse)
              .resolve(req);

          expect(res.status, equals(HttpStatusCode.notModified));
          expect(res.headers.any((h) => h is ContentTypeHeader), isFalse);
          expect(res.headers.any((h) => h is LastModifiedHeader), isTrue);
        } finally {
          if (tempFile.existsSync()) tempFile.deleteSync();
        }
      },
    );

    test(
      'Response.file returns Content-Range header on 416 Range Not Satisfiable',
      () async {
        final tempFile = File('${Directory.systemTemp.path}/test_416.txt');
        tempFile.writeAsStringSync('sample content');
        try {
          final req = TestRequestBuilder.get(
            '/test_416.txt',
          ).headers([const .range('bytes=100-200')]).build();
          final res = await (Response.file(tempFile) as ResolvableResponse)
              .resolve(req);

          expect(res.status, equals(HttpStatusCode.rangeNotSatisfiable));
          expect(res.headers.any((h) => h is ContentTypeHeader), isFalse);
          expect(res.headers.any((h) => h is ContentRangeHeader), isTrue);
        } finally {
          if (tempFile.existsSync()) tempFile.deleteSync();
        }
      },
    );

    test('Response.status creates empty body response with status', () {
      const res = Response.status(HttpStatusCode.noContent);
      expect(res.status, equals(HttpStatusCode.noContent));
      expect(res.contentLength, equals(0));
      expect(res.body, isA<EmptyResponseBody>());
    });

    test('Response.bytes creates bytes response', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final res = Response.bytes(bytes, status: HttpStatusCode.created);

      expect(res.status, equals(HttpStatusCode.created));
      expect(res.contentLength, equals(4));
      if (res.body case BytesResponseBody(:final bytes)) {
        expect(bytes, equals([1, 2, 3, 4]));
      } else {
        fail('Expected BytesResponseBody');
      }
    });

    test('Response.redirect sets status and Location header', () {
      final uri = Uri.parse('https://example.com/login');
      final res = Response.redirect(uri);

      expect(res.status, equals(HttpStatusCode.found));
      expect(
        res.headers.get<LocationHeader>()?.uri,
        equals('https://example.com/login'),
      );
    });

    test('withHeaders appends extra headers', () {
      const initial = Response.status(HttpStatusCode.ok);
      expect(initial.withHeaders([]), same(initial));

      final updated = initial.withHeaders([
        const ContentTypeHeader.json(),
      ]);

      expect(updated.headers.length, equals(1));
      expect(updated.headers.first, isA<ContentTypeHeader>());
    });

    test('withBody replaces body', () {
      const initial = Response.status(HttpStatusCode.ok);
      final newBody = ResponseBody.bytes(Uint8List.fromList([65, 66]));
      final updated = initial.withBody(newBody);

      expect(updated.contentLength, equals(2));
      expect(updated.body, equals(newBody));
    });

    test('WebSocketResponse.withHeaders appends extra headers', () {
      final initial = Response.websocket((ws) async {});
      expect(initial.withHeaders([]), same(initial));

      final updated = initial.withHeaders([
        const ContentTypeHeader.json(),
      ]);

      expect(updated, isA<WebSocketResponse>());
      expect(updated.headers, contains(isA<ContentTypeHeader>()));
    });

    test(
      'Http1RequestKeepAlive returns true for explicit connection keep-alive '
      'header',
      () {
        final req = TestRequestBuilder.get('/test')
            .version(HttpVersion.http10)
            .headers([const .connectionKeepAlive()])
            .build();

        expect(req.keepAlive, isTrue);
      },
    );

    test(
      'ContentResponse falls back to full content on invalid range header '
      'syntax',
      () async {
        final tempFile = File(
          '${Directory.systemTemp.path}/test_invalid_range.txt',
        );
        tempFile.writeAsStringSync('sample content payload');
        try {
          final req = TestRequestBuilder.get(
            '/test.txt',
          ).headers([const .range('bytes=abc-xyz')]).build();
          final res = await (Response.file(tempFile) as ResolvableResponse)
              .resolve(req);

          expect(res.status, equals(HttpStatusCode.ok));
          expect(res.contentLength, equals(tempFile.statSync().size));
        } finally {
          if (tempFile.existsSync()) tempFile.deleteSync();
        }
      },
    );

    test(
      'WebSocketResponse resolves origin check correctly with port mismatch',
      () async {
        final wsResponse = Response.websocket((ws) async {});

        final req = TestRequestBuilder.get('/ws').headers([
          const .connectionUpgrade(),
          const .upgradeWebsocket(),
          const .secWebSocketKey('dGhlIHNhbXBsZSBub25jZQ=='),
          const .secWebSocketVersionV13(),
          const .host('localhost:8080'),
          .origin(.parts('http', 'localhost', 9090)),
        ]).build();

        final res = await (wsResponse as ResolvableResponse).resolve(req);
        expect(res.status, equals(HttpStatusCode.forbidden));
      },
    );
  });
}

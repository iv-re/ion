import 'dart:io';

import 'package:ion_web/ion_web.dart';
import 'package:test/test.dart';

import '../helpers/helpers.dart';

void main() {
  group('Response.content', () {
    final sampleData = utf8.encode('0123456789abcdefghijklmnopqrstuvwxyz');
    final lastModified = DateTime.utc(2025, 5, 20, 10);
    final etag = ETagHeader.strong('v1-sample');

    Future<Response> createResponse(
      Request request, {
      List<TypedHeader> extraHeaders = const [],
      ETagHeader? customEtag,
    }) async {
      final etagToUse = customEtag ?? etag;
      return (Response.content(
                read: (start, end) {
                  final slice = sampleData.sublist(start, end);
                  return Stream.value(Uint8List.fromList(slice));
                },
                size: sampleData.length,
                name: 'document.txt',
                lastModified: lastModified,
                headers: [
                  etagToUse,
                  ...extraHeaders,
                ],
              )
              as ResolvableResponse)
          .resolve(request);
    }

    test(
      'returns 200 OK full content with inferred Content-Type and headers',
      () async {
        final req = TestRequestBuilder.get('/file.txt').build();
        final res = await createResponse(req);

        expect(res.status, equals(HttpStatusCode.ok));
        expect(res.headers.has<AcceptRangesHeader>(), isTrue);
        expect(
          res.headers.get<ContentTypeHeader>()?.value,
          equals('text/plain'),
        );
        expect(res.contentLength, equals(sampleData.length));
        expect(res.headers.get<ETagHeader>()?.value, equals('"v1-sample"'));

        final bytes = await readResponseBodyBytes(res);
        expect(bytes, equals(sampleData));
      },
    );

    test('returns 206 Partial Content for valid range request', () async {
      final req = TestRequestBuilder.get(
        '/file.txt',
      ).headers([const .range('bytes=0-9')]).build();
      final res = await createResponse(req);

      expect(res.status, equals(HttpStatusCode.partialContent));
      expect(
        res.headers.get<ContentRangeHeader>()?.value,
        equals('bytes 0-9/${sampleData.length}'),
      );
      expect(res.contentLength, equals(10));

      final text = await readResponseBodyText(res);
      expect(text, equals('0123456789'));
    });

    test(
      'returns 416 Range Not Satisfiable when range is out of bounds',
      () async {
        final req = TestRequestBuilder.get(
          '/file.txt',
        ).headers([const .range('bytes=1000-2000')]).build();
        final res = await createResponse(req);

        expect(res.status, equals(HttpStatusCode.rangeNotSatisfiable));
        expect(
          res.headers.get<ContentRangeHeader>()?.value,
          equals('bytes */${sampleData.length}'),
        );
      },
    );

    test('returns 304 Not Modified when If-None-Match matches ETag', () async {
      final req = TestRequestBuilder.get('/file.txt').headers([
        IfNoneMatchHeader.etag(const EntityTag('v1-sample')),
      ]).build();
      final res = await createResponse(req);

      expect(res.status, equals(HttpStatusCode.notModified));
      expect(res.headers.get<ETagHeader>()?.value, equals('"v1-sample"'));
      expect(res.body, isA<EmptyResponseBody>());
    });

    test(
      'returns 304 Not Modified when If-Modified-Since is un-modified',
      () async {
        final req = TestRequestBuilder.get(
          '/file.txt',
        ).headers([TypedHeader.ifModifiedSince(lastModified)]).build();
        final res = await createResponse(req);

        expect(res.status, equals(HttpStatusCode.notModified));
      },
    );

    test(
      'returns 412 Precondition Failed when If-Match does not match',
      () async {
        final req = TestRequestBuilder.get('/file.txt').headers([
          IfMatchHeader.etag(const EntityTag('other-etag')),
        ]).build();
        final res = await createResponse(req);

        expect(res.status, equals(HttpStatusCode.preconditionFailed));
      },
    );

    test('HEAD request returns headers but no body', () async {
      var readInvoked = false;
      final req = TestRequestBuilder.head('/file.txt').build();
      final res =
          await (Response.content(
                    read: (start, end) {
                      readInvoked = true;
                      return Stream.value(Uint8List.fromList(sampleData));
                    },
                    size: sampleData.length,
                    name: 'image.png',
                    lastModified: lastModified,
                    headers: [etag],
                  )
                  as ResolvableResponse)
              .resolve(req);

      expect(res.status, equals(HttpStatusCode.ok));
      expect(res.headers.get<ContentTypeHeader>()?.value, equals('image/png'));
      expect(res.contentLength, equals(sampleData.length));
      final bytes = await readResponseBodyBytes(res);
      expect(bytes, isEmpty);
      expect(readInvoked, isFalse);
    });

    test('custom headers override default Content-Type', () async {
      final req = TestRequestBuilder.get('/file.txt').build();
      final res =
          await (Response.content(
                    read: (start, end) => Stream.value(Uint8List(0)),
                    size: 0,
                    name: 'file.txt',
                    lastModified: lastModified,
                    headers: const [.contentType('custom/mime')],
                  )
                  as ResolvableResponse)
              .resolve(req);

      expect(
        res.headers.get<ContentTypeHeader>()?.value,
        equals('custom/mime'),
      );
    });

    test('extracts ETag from headers when etag parameter is null', () async {
      final req = TestRequestBuilder.get('/file.txt').headers([
        IfNoneMatchHeader.etag(const EntityTag('from-headers')),
      ]).build();
      final res =
          await (Response.content(
                    read: (start, end) => Stream.value(Uint8List(0)),
                    size: 0,
                    name: 'file.txt',
                    lastModified: lastModified,
                    headers: [ETagHeader.strong('from-headers')],
                  )
                  as ResolvableResponse)
              .resolve(req);

      expect(res.status, equals(HttpStatusCode.notModified));
      expect(res.headers.get<ETagHeader>()?.value, equals('"from-headers"'));
    });

    test(
      'detects MIME type from magic header bytes when extension is unknown',
      () async {
        final pngHeader = Uint8List.fromList([
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
        ]);

        final req = TestRequestBuilder.get('/file.txt').build();
        final res =
            await (Response.content(
                      read: (start, end) => Stream.value(
                        Uint8List.fromList(pngHeader.sublist(start, end)),
                      ),
                      size: pngHeader.length,
                      name: 'unknown_file_without_ext',
                      lastModified: lastModified,
                    )
                    as ResolvableResponse)
                .resolve(req);

        expect(
          res.headers.get<ContentTypeHeader>()?.value,
          equals('image/png'),
        );
      },
    );
  });

  group('Response.file', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ion_web_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('serves existing file with 200 OK and correct content', () async {
      final file = File('${tempDir.path}/hello.txt');
      await file.writeAsString('Hello from file!');

      final req = TestRequestBuilder.get('/sample.txt').build();
      final res = await (Response.file(file) as ResolvableResponse).resolve(
        req,
      );

      expect(res.status, equals(HttpStatusCode.ok));
      expect(res.headers.get<ContentTypeHeader>()?.value, equals('text/plain'));
      expect(res.contentLength, equals(16));

      final text = await readResponseBodyText(res);
      expect(text, equals('Hello from file!'));
    });

    test('returns 404 Not Found for non-existent file', () async {
      final file = File('${tempDir.path}/non_existent.txt');

      final req = TestRequestBuilder.get('/sample.txt').build();
      final res = await (Response.file(file) as ResolvableResponse).resolve(
        req,
      );

      expect(res.status, equals(HttpStatusCode.notFound));
    });
  });
}

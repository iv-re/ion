import 'package:http_headers/src/headers/content_type.dart';
import 'package:test/test.dart';

void main() {
  group('ContentTypeHeader', () {
    test('decodes mediaType, charset, and boundary correctly', () {
      final header = ContentTypeHeader.decode([
        'text/html; charset=utf-8; boundary=something',
      ]);
      expect(header, isA<ContentTypeHeader>());
      expect(header?.mediaType, equals('text/html'));
      expect(header?.charset, equals('utf-8'));
      expect(header?.boundary, equals('something'));
      expect(
        header?.encode(),
        equals(['text/html; charset=utf-8; boundary=something']),
      );
    });

    test('verifies convenience constructors and encoding', () {
      expect(
        const ContentTypeHeader.json().encode(),
        equals(['application/json']),
      );
      expect(
        const ContentTypeHeader.jsonUtf8().encode(),
        equals(['application/json; charset=utf-8']),
      );
      expect(
        const ContentTypeHeader.jsonProblem().encode(),
        equals(['application/problem+json']),
      );
      expect(
        const ContentTypeHeader.eventStream().encode(),
        equals(['text/event-stream']),
      );
      expect(
        const ContentTypeHeader.ndjson().encode(),
        equals(['application/x-ndjson']),
      );
      expect(const ContentTypeHeader.text().encode(), equals(['text/plain']));
      expect(
        const ContentTypeHeader.textUtf8().encode(),
        equals(['text/plain; charset=utf-8']),
      );
      expect(const ContentTypeHeader.html().encode(), equals(['text/html']));
      expect(const ContentTypeHeader.xml().encode(), equals(['text/xml']));
      expect(
        const ContentTypeHeader.formUrlEncoded().encode(),
        equals(['application/x-www-form-urlencoded']),
      );
      expect(
        const ContentTypeHeader.multipartFormData().encode(),
        equals(['multipart/form-data']),
      );
      expect(
        const ContentTypeHeader.multipartFormData(boundary: 'bound').encode(),
        equals(['multipart/form-data; boundary=bound']),
      );
      expect(const ContentTypeHeader.jpeg().encode(), equals(['image/jpeg']));
      expect(const ContentTypeHeader.png().encode(), equals(['image/png']));
      expect(const ContentTypeHeader.webp().encode(), equals(['image/webp']));
      expect(const ContentTypeHeader.svg().encode(), equals(['image/svg+xml']));
      expect(
        const ContentTypeHeader.pdf().encode(),
        equals(['application/pdf']),
      );
      expect(
        const ContentTypeHeader.octetStream().encode(),
        equals(['application/octet-stream']),
      );
      expect(
        const ContentTypeHeader.protobuf().encode(),
        equals(['application/x-protobuf']),
      );
    });

    test('encodes dynamic custom header correctly without StringBuffer', () {
      const header1 = ContentTypeHeader('application/custom');
      expect(header1.encode(), equals(['application/custom']));

      const header2 = ContentTypeHeader(
        'application/custom',
        charset: 'utf-8',
      );
      expect(header2.encode(), equals(['application/custom; charset=utf-8']));

      const header3 = ContentTypeHeader(
        'application/custom',
        boundary: 'abc',
      );
      expect(header3.encode(), equals(['application/custom; boundary=abc']));
    });

    test('returns null for empty values', () {
      expect(ContentTypeHeader.decode([]), isNull);
      expect(ContentTypeHeader.decode(['   ']), isNull);
    });
  });
}

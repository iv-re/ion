import 'package:http_headers/src/headers/content_encoding.dart';
import 'package:test/test.dart';

void main() {
  group('ContentEncodingHeader', () {
    test('decodes codings list correctly', () {
      final header = ContentEncodingHeader.decode(['gzip, br']);
      expect(header, isA<ContentEncodingHeader>());
      expect(header?.codings, equals(['gzip', 'br']));
      expect(header?.contains('GZIP'), isTrue);
      expect(header?.contains('br'), isTrue);
      expect(header?.contains('deflate'), isFalse);
      expect(header?.encode(), equals(['gzip, br']));
    });

    test('gzip factory constructor works correctly', () {
      const gz = ContentEncodingHeader.gzip();
      expect(gz.codings, equals(['gzip']));
      expect(gz.encode(), equals(['gzip']));
    });

    test('returns null for empty values', () {
      expect(ContentEncodingHeader.decode([]), isNull);
    });
  });
}

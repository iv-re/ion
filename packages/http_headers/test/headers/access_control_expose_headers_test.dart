import 'package:http_headers/src/headers/access_control_expose_headers.dart';
import 'package:test/test.dart';

void main() {
  group('AccessControlExposeHeadersHeader', () {
    test('decodes headers list correctly', () {
      final header = AccessControlExposeHeadersHeader.decode([
        'ETag, Content-Length',
      ]);
      expect(header, isA<AccessControlExposeHeadersHeader>());
      expect(header?.headers, equals(['ETag', 'Content-Length']));
      expect(header?.encode(), equals(['ETag, Content-Length']));
    });

    test('returns null for empty values', () {
      expect(AccessControlExposeHeadersHeader.decode([]), isNull);
    });
  });
}

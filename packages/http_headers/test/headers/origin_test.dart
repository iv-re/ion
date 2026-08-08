import 'package:http_headers/src/headers/origin.dart';
import 'package:test/test.dart';

void main() {
  group('OriginHeader', () {
    test('decodes null origin correctly', () {
      final header = OriginHeader.decode(['null']);
      expect(header, isA<OriginNull>());
      expect(header?.isNull, isTrue);
      expect(header?.encode(), equals(['null']));
    });

    test('decodes origin URL with port correctly', () {
      final header = OriginHeader.decode(['http://web-platform.test:8000']);
      expect(header, isA<OriginValue>());
      expect(header?.isNull, isFalse);
      expect(header?.scheme, equals('http'));
      expect(header?.host, equals('web-platform.test'));
      expect(header?.hostname, equals('web-platform.test'));
      expect(header?.port, equals(8000));
      expect(header?.encode(), equals(['http://web-platform.test:8000']));
    });

    test('constructs via parts factory constructor', () {
      final constructed = OriginHeader.parts('https', 'example.com', 443);
      expect(constructed.encode(), equals(['https://example.com:443']));
    });

    test('returns null for invalid inputs or empty values', () {
      expect(OriginHeader.decode(['invalid-url']), isNull);
      expect(OriginHeader.decode([]), isNull);
    });
  });
}

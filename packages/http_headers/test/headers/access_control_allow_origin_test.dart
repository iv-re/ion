import 'package:http_headers/src/headers/access_control_allow_origin.dart';
import 'package:test/test.dart';

void main() {
  group('AccessControlAllowOriginHeader', () {
    test('decodes wildcard correctly', () {
      final header = AccessControlAllowOriginHeader.decode(['*']);
      expect(header, isA<AccessControlAllowOriginAny>());
      expect(header?.isAny, isTrue);
      expect(header?.isNull, isFalse);
      expect(header?.origin, isNull);
      expect(header?.encode(), equals(['*']));
    });

    test('decodes null origin correctly', () {
      final header = AccessControlAllowOriginHeader.decode(['null']);
      expect(header, isA<AccessControlAllowOriginNull>());
      expect(header?.isAny, isFalse);
      expect(header?.isNull, isTrue);
      expect(header?.origin, isNull);
      expect(header?.encode(), equals(['null']));
    });

    test('decodes custom origin correctly', () {
      final header = AccessControlAllowOriginHeader.decode([
        'https://example.com',
      ]);
      expect(header, isA<AccessControlAllowOriginValue>());
      expect(header?.isAny, isFalse);
      expect(header?.isNull, isFalse);
      expect(header?.origin, equals('https://example.com'));
      expect(header?.encode(), equals(['https://example.com']));
    });

    test('returns null for empty values', () {
      expect(AccessControlAllowOriginHeader.decode([]), isNull);
      expect(AccessControlAllowOriginHeader.decode(['   ']), isNull);
    });
  });
}

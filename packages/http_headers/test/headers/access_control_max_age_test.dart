import 'package:http_headers/src/headers/access_control_max_age.dart';
import 'package:test/test.dart';

void main() {
  group('AccessControlMaxAgeHeader', () {
    test('decodes seconds correctly', () {
      final header = AccessControlMaxAgeHeader.decode(['531']);
      expect(header, isA<AccessControlMaxAgeHeader>());
      expect(header?.duration, equals(const Duration(seconds: 531)));
      expect(header?.encode(), equals(['531']));
    });

    test('returns null for invalid or empty values', () {
      expect(AccessControlMaxAgeHeader.decode(['invalid']), isNull);
      expect(AccessControlMaxAgeHeader.decode([]), isNull);
    });
  });
}

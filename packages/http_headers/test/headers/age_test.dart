import 'package:http_headers/src/headers/age.dart';
import 'package:test/test.dart';

void main() {
  group('AgeHeader', () {
    test('decodes seconds correctly', () {
      final header = AgeHeader.decode(['3600']);
      expect(header, isA<AgeHeader>());
      expect(header?.duration, equals(const Duration(seconds: 3600)));
      expect(header?.encode(), equals(['3600']));
    });

    test('returns null for invalid or negative seconds', () {
      expect(AgeHeader.decode(['-10']), isNull);
      expect(AgeHeader.decode(['invalid']), isNull);
      expect(AgeHeader.decode([]), isNull);
    });
  });
}

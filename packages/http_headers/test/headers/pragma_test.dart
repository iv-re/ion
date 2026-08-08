import 'package:http_headers/src/headers/pragma.dart';
import 'package:test/test.dart';

void main() {
  group('PragmaHeader', () {
    test('decodes no-cache correctly', () {
      final header = PragmaHeader.decode(['no-cache']);
      expect(header, isA<PragmaHeader>());
      expect(header?.isNoCache, isTrue);
      expect(header?.encode(), equals(['no-cache']));
    });

    test('decodes custom pragma value correctly', () {
      final header = PragmaHeader.decode(['custom-pragma']);
      expect(header?.value, equals('custom-pragma'));
      expect(header?.isNoCache, isFalse);
    });

    test('returns null for empty values', () {
      expect(PragmaHeader.decode([]), isNull);
      expect(PragmaHeader.decode(['   ']), isNull);
    });
  });
}

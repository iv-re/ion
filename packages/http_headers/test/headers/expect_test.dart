import 'package:http_headers/src/headers/expect.dart';
import 'package:test/test.dart';

void main() {
  group('ExpectHeader', () {
    test('decodes 100-continue correctly', () {
      final header = ExpectHeader.decode(['100-continue']);
      expect(header, equals(const ExpectHeader.continue100()));
      expect(header?.encode(), equals(['100-continue']));
    });

    test('returns null for other values or empty list', () {
      expect(ExpectHeader.decode(['something-else']), isNull);
      expect(ExpectHeader.decode([]), isNull);
    });
  });
}

import 'package:http_headers/src/headers/vary.dart';
import 'package:test/test.dart';

void main() {
  group('VaryHeader', () {
    test('decodes header names list correctly', () {
      final header = VaryHeader.decode(['accept-encoding, accept-language']);
      expect(header, isA<VaryHeader>());
      expect(
        header?.headers,
        equals(['accept-encoding', 'accept-language']),
      );
      expect(
        header?.encode(),
        equals(['accept-encoding, accept-language']),
      );
    });

    test('decodes wildcard Vary:* correctly', () {
      final header = VaryHeader.decode(['*']);
      expect(header?.isAny, isTrue);
      expect(header?.encode(), equals(['*']));
    });

    test('returns null for empty values', () {
      expect(VaryHeader.decode([]), isNull);
    });
  });
}

import 'package:http_headers/src/headers/range.dart';
import 'package:test/test.dart';

void main() {
  group('RangeHeader', () {
    test('decodes bytes range correctly and calculates ranges', () {
      final header = RangeHeader.decode(['bytes=0-499']);
      expect(header, isA<RangeHeader>());
      expect(header?.raw, equals('bytes=0-499'));
      expect(header?.encode(), equals(['bytes=0-499']));
      final ranges = header?.ranges(1000);
      expect(ranges, hasLength(1));
      expect(ranges?.first.start, equals(0));
      expect(ranges?.first.length, equals(500));
    });

    test('calculates suffix ranges and verifies factory constructor', () {
      const suffixRange = RangeHeader('bytes=-500');
      final ranges = suffixRange.ranges(1000);
      expect(ranges, hasLength(1));
      expect(ranges.first.start, equals(500));
      expect(ranges.first.length, equals(500));

      final factoryRange = RangeHeader.bytes(100, 200);
      expect(factoryRange.encode(), equals(['bytes=100-200']));
    });

    test('returns null for empty or invalid values', () {
      expect(RangeHeader.decode(['invalid']), isNull);
      expect(RangeHeader.decode([]), isNull);
    });
  });
}

import 'package:http_headers/src/headers/accept_ranges.dart';
import 'package:test/test.dart';

void main() {
  group('AcceptRangesHeader', () {
    test('decodes bytes correctly', () {
      final header = AcceptRangesHeader.decode(['bytes']);
      expect(header, isNotNull);
      expect(header?.isBytes, isTrue);
      expect(header?.isNone, isFalse);
      expect(header?.encode(), equals(['bytes']));
    });

    test('decodes none correctly', () {
      final header = AcceptRangesHeader.decode(['none']);
      expect(header, isNotNull);
      expect(header?.isBytes, isFalse);
      expect(header?.isNone, isTrue);
      expect(header?.encode(), equals(['none']));
    });

    test('decodes custom range unit', () {
      final header = AcceptRangesHeader.decode(['items']);
      expect(header?.rangeUnit, equals('items'));
      expect(header?.isBytes, isFalse);
      expect(header?.isNone, isFalse);
      expect(header?.encode(), equals(['items']));
    });

    test('returns null for empty values', () {
      expect(AcceptRangesHeader.decode([]), isNull);
      expect(AcceptRangesHeader.decode(['   ']), isNull);
    });
  });
}

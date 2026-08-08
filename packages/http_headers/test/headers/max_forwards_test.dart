import 'package:http_headers/src/headers/max_forwards.dart';
import 'package:test/test.dart';

void main() {
  group('MaxForwardsHeader', () {
    test('decodes correctly', () {
      final header = MaxForwardsHeader.decode(['10']);
      expect(header, isNotNull);
      expect(header?.count, equals(10));
      expect(header?.encode(), equals(['10']));
    });

    test('returns null for empty values or invalid numbers', () {
      expect(MaxForwardsHeader.decode([]), isNull);
      expect(MaxForwardsHeader.decode(['   ']), isNull);
      expect(MaxForwardsHeader.decode(['abc']), isNull);
      expect(MaxForwardsHeader.decode(['-1']), isNull);
    });

    test('toString is formatted correctly', () {
      const header = MaxForwardsHeader(5);
      expect(header.toString(), equals('MaxForwardsHeader(5)'));
    });
  });
}

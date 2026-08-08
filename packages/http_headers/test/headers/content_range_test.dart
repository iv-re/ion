import 'package:http_headers/src/headers/content_range.dart';
import 'package:test/test.dart';

void main() {
  group('ContentRangeHeader', () {
    test('decodes byte range and total length correctly', () {
      final header = ContentRangeHeader.decode(['bytes 200-1000/67589']);
      expect(header, isA<ContentRangeHeader>());
      expect(header?.start, equals(200));
      expect(header?.end, equals(1000));
      expect(header?.completeLength, equals(67589));
      expect(header?.bytesRange, equals((200, 1000)));
      expect(header?.bytesLen, equals(67589));
      expect(header?.encode(), equals(['bytes 200-1000/67589']));
    });

    test('decodes unsatisfied byte range correctly', () {
      final header = ContentRangeHeader.decode(['bytes */67589']);
      expect(header, isNotNull);
      expect(header?.start, isNull);
      expect(header?.end, isNull);
      expect(header?.completeLength, equals(67589));
      expect(header?.bytesRange, isNull);
      expect(header?.encode(), equals(['bytes */67589']));
    });

    test('returns null for invalid inputs', () {
      expect(ContentRangeHeader.decode(['invalid']), isNull);
      expect(ContentRangeHeader.decode(['bytes 100-50/100']), isNull);
      expect(ContentRangeHeader.decode([]), isNull);
    });
  });
}

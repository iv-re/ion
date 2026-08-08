import 'package:http_headers/src/headers/content_length.dart';
import 'package:test/test.dart';

void main() {
  group('ContentLengthHeader', () {
    test('decodes bytes count correctly', () {
      final header = ContentLengthHeader.decode(['1024']);
      expect(header, isA<ContentLengthHeader>());
      expect(header?.bytes, equals(1024));
      expect(header?.length, equals(1024));
      expect(header?.encode(), equals(['1024']));
    });

    test('returns null for negative or invalid content-length values', () {
      expect(ContentLengthHeader.decode(['-10']), isNull);
      expect(ContentLengthHeader.decode(['+10']), isNull);
      expect(ContentLengthHeader.decode(['10.0']), isNull);
      expect(ContentLengthHeader.decode(['invalid']), isNull);
      expect(ContentLengthHeader.decode([]), isNull);
    });

    test('returns null for conflicting content-length values', () {
      expect(ContentLengthHeader.decode(['100', '200']), isNull);
    });

    test('decodes matching multiple content-length values', () {
      final header = ContentLengthHeader.decode(['100', '100']);
      expect(header?.bytes, equals(100));
    });
  });
}

import 'package:http_headers/src/headers/x_content_type_options.dart';
import 'package:test/test.dart';

void main() {
  group('XContentTypeOptionsHeader', () {
    test('decodes nosniff correctly', () {
      final header = XContentTypeOptionsHeader.decode(['nosniff']);
      expect(header, isNotNull);
      expect(header?.options, equals('nosniff'));
      expect(header?.encode(), equals(['nosniff']));
    });

    test('decodes custom correctly', () {
      final header = XContentTypeOptionsHeader.decode(['custom-value']);
      expect(header, isNotNull);
      expect(header?.options, equals('custom-value'));
      expect(header?.encode(), equals(['custom-value']));
    });

    test('returns null for empty values', () {
      expect(XContentTypeOptionsHeader.decode([]), isNull);
      expect(XContentTypeOptionsHeader.decode(['   ']), isNull);
    });

    test('toString is formatted correctly', () {
      const header = XContentTypeOptionsHeader.nosniff();
      expect(header.toString(), equals('XContentTypeOptionsHeader(nosniff)'));
    });
  });
}

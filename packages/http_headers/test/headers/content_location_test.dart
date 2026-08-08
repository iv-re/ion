import 'package:http_headers/src/headers/content_location.dart';
import 'package:test/test.dart';

void main() {
  group('ContentLocationHeader', () {
    test('decodes URI string correctly', () {
      final header = ContentLocationHeader.decode([
        '/hypertext/Overview.html',
      ]);
      expect(header, isA<ContentLocationHeader>());
      expect(header?.uri, equals('/hypertext/Overview.html'));
      expect(header?.encode(), equals(['/hypertext/Overview.html']));
    });

    test('returns null for empty values', () {
      expect(ContentLocationHeader.decode([]), isNull);
      expect(ContentLocationHeader.decode(['   ']), isNull);
    });
  });
}

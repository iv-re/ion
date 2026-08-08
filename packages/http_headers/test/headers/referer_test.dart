import 'package:http_headers/src/headers/referer.dart';
import 'package:test/test.dart';

void main() {
  group('RefererHeader', () {
    test('decodes URI correctly', () {
      final header = RefererHeader.decode([
        'http://www.example.org/hypertext/Overview.html',
      ]);
      expect(header, isA<RefererHeader>());
      expect(
        header?.uri,
        equals('http://www.example.org/hypertext/Overview.html'),
      );
      expect(
        header?.encode(),
        equals(['http://www.example.org/hypertext/Overview.html']),
      );
    });

    test('returns null for empty values', () {
      expect(RefererHeader.decode([]), isNull);
      expect(RefererHeader.decode(['   ']), isNull);
    });
  });
}

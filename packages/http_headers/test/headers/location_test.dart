import 'package:http_headers/src/headers/location.dart';
import 'package:test/test.dart';

void main() {
  group('LocationHeader', () {
    test('decodes URI reference correctly', () {
      final header = LocationHeader.decode(['/People.html#tim']);
      expect(header, isA<LocationHeader>());
      expect(header?.uri, equals('/People.html#tim'));
      expect(header?.encode(), equals(['/People.html#tim']));
    });

    test('returns null for empty values', () {
      expect(LocationHeader.decode([]), isNull);
      expect(LocationHeader.decode(['   ']), isNull);
    });
  });
}

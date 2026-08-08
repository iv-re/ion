import 'package:http_headers/src/headers/from.dart';
import 'package:test/test.dart';

void main() {
  group('FromHeader', () {
    test('decodes correctly', () {
      final header = FromHeader.decode(['webmaster@example.org']);
      expect(header, isNotNull);
      expect(header?.email, equals('webmaster@example.org'));
      expect(header?.encode(), equals(['webmaster@example.org']));
    });

    test('returns null for empty values', () {
      expect(FromHeader.decode([]), isNull);
      expect(FromHeader.decode(['   ']), isNull);
    });

    test('toString is formatted correctly', () {
      const header = FromHeader('admin@test.com');
      expect(header.toString(), equals('FromHeader(admin@test.com)'));
    });
  });
}

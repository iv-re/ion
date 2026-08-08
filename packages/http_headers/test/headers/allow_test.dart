import 'package:http_headers/src/headers/allow.dart';
import 'package:test/test.dart';

void main() {
  group('AllowHeader', () {
    test('decodes allowed methods correctly', () {
      final header = AllowHeader.decode(['GET, POST, PUT']);
      expect(header, isA<AllowHeader>());
      expect(header?.methods, equals(['GET', 'POST', 'PUT']));
      expect(header?.encode(), equals(['GET, POST, PUT']));
    });

    test('returns null for empty values', () {
      expect(AllowHeader.decode([]), isNull);
    });
  });
}

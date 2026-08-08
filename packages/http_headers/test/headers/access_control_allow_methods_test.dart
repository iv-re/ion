import 'package:http_headers/src/headers/access_control_allow_methods.dart';
import 'package:test/test.dart';

void main() {
  group('AccessControlAllowMethodsHeader', () {
    test('decodes methods list correctly', () {
      final header = AccessControlAllowMethodsHeader.decode(['GET, POST, PUT']);
      expect(header, isA<AccessControlAllowMethodsHeader>());
      expect(header?.methods, equals(['GET', 'POST', 'PUT']));
      expect(header?.encode(), equals(['GET, POST, PUT']));
    });

    test('returns null for empty values', () {
      expect(AccessControlAllowMethodsHeader.decode([]), isNull);
    });
  });
}

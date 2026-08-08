import 'package:http_headers/src/headers/access_control_request_method.dart';
import 'package:test/test.dart';

void main() {
  group('AccessControlRequestMethodHeader', () {
    test('decodes method correctly', () {
      final header = AccessControlRequestMethodHeader.decode(['GET']);
      expect(header, isA<AccessControlRequestMethodHeader>());
      expect(header?.method, equals('GET'));
      expect(header?.encode(), equals(['GET']));
    });

    test('returns null for empty values', () {
      expect(AccessControlRequestMethodHeader.decode([]), isNull);
      expect(AccessControlRequestMethodHeader.decode(['   ']), isNull);
    });
  });
}

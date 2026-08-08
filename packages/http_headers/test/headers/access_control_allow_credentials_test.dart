import 'package:http_headers/src/headers/access_control_allow_credentials.dart';
import 'package:test/test.dart';

void main() {
  group('AccessControlAllowCredentialsHeader', () {
    test('decodes true correctly', () {
      final header = AccessControlAllowCredentialsHeader.decode(['true']);
      expect(
        header,
        equals(const AccessControlAllowCredentialsHeader()),
      );
      expect(header?.encode(), equals(['true']));
    });

    test('returns null for values other than true or empty values', () {
      expect(AccessControlAllowCredentialsHeader.decode(['false']), isNull);
      expect(AccessControlAllowCredentialsHeader.decode([]), isNull);
    });
  });
}

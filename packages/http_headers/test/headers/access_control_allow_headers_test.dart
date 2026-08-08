import 'package:http_headers/src/headers/access_control_allow_headers.dart';
import 'package:test/test.dart';

void main() {
  group('AccessControlAllowHeadersHeader', () {
    test('decodes headers list correctly', () {
      final header = AccessControlAllowHeadersHeader.decode([
        'accept-language, date',
      ]);
      expect(header, isA<AccessControlAllowHeadersHeader>());
      expect(header?.headers, equals(['accept-language', 'date']));
      expect(header?.encode(), equals(['accept-language, date']));
    });

    test('returns null for empty values', () {
      expect(AccessControlAllowHeadersHeader.decode([]), isNull);
    });
  });
}

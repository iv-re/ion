import 'package:http_headers/src/headers/access_control_request_headers.dart';
import 'package:test/test.dart';

void main() {
  group('AccessControlRequestHeadersHeader', () {
    test('decodes header names correctly', () {
      final header = AccessControlRequestHeadersHeader.decode([
        'accept-language, date',
      ]);
      expect(header, isA<AccessControlRequestHeadersHeader>());
      expect(header?.headers, equals(['accept-language', 'date']));
      expect(header?.encode(), equals(['accept-language, date']));
    });

    test('returns null for empty values', () {
      expect(AccessControlRequestHeadersHeader.decode([]), isNull);
    });
  });
}

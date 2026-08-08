import 'package:http_headers/src/headers/user_agent.dart';
import 'package:test/test.dart';

void main() {
  group('UserAgentHeader', () {
    test('decodes user agent string correctly', () {
      final header = UserAgentHeader.decode(['hyper/0.12.2']);
      expect(header, isA<UserAgentHeader>());
      expect(header?.value, equals('hyper/0.12.2'));
      expect(header?.encode(), equals(['hyper/0.12.2']));
    });

    test('returns null for empty values', () {
      expect(UserAgentHeader.decode([]), isNull);
      expect(UserAgentHeader.decode(['   ']), isNull);
    });
  });
}

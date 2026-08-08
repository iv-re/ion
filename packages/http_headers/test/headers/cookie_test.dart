import 'package:http_headers/src/headers/cookie.dart';
import 'package:test/test.dart';

void main() {
  group('CookieHeader', () {
    test('decodes cookie pairs correctly', () {
      final header = CookieHeader.decode([
        'SID=31d4d96e407aad42; lang=en-US',
      ]);
      expect(header, isA<CookieHeader>());
      expect(header?.length, equals(2));
      expect(header?['SID'], equals('31d4d96e407aad42'));
      expect(header?.get('lang'), equals('en-US'));
      expect(
        header?.encode(),
        equals(['SID=31d4d96e407aad42; lang=en-US']),
      );
    });

    test('returns null for empty values', () {
      expect(CookieHeader.decode([]), isNull);
    });

    test('limits parsed cookies to maxCookies', () {
      final header = CookieHeader.decode([
        'c1=1; c2=2; c3=3; c4=4; c5=5',
      ], maxCookies: 3);
      expect(header, isNotNull);
      expect(header?.length, equals(3));
      expect(header?.cookies.keys, equals(['c1', 'c2', 'c3']));
    });
  });
}

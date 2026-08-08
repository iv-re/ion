import 'dart:io';

import 'package:http_headers/src/headers/set_cookie.dart';
import 'package:test/test.dart';

void main() {
  group('SetCookieHeader', () {
    test('decodes multiple Set-Cookie headers correctly', () {
      final header = SetCookieHeader.decode([
        'SID=31d4d96e407aad42; Path=/; HttpOnly',
        'lang=en-US',
      ]);
      expect(header, isA<SetCookieHeader>());
      expect(header?.cookies, hasLength(2));
      expect(header?.cookies.first.name, equals('SID'));
      expect(header?.cookies.first.value, equals('31d4d96e407aad42'));
      expect(header?.cookies.first.path, equals('/'));
      expect(header?.cookies.first.httpOnly, isTrue);
    });

    test('creates header from single cookie object', () {
      final single = SetCookieHeader.fromCookie(
        Cookie('theme', 'dark')
          ..path = '/'
          ..httpOnly = true,
      );
      expect(single.encode(), equals(['theme=dark; Path=/; HttpOnly']));
    });

    test('returns null for empty or invalid values', () {
      expect(SetCookieHeader.decode([]), isNull);
    });
  });
}

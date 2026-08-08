import 'package:http_headers/src/headers/authorization.dart';
import 'package:test/test.dart';

void main() {
  group('AuthorizationHeader', () {
    test('decodes Bearer token correctly', () {
      final header = AuthorizationHeader.decode(['Bearer myToken123']);
      expect(header, isA<AuthorizationBearer>());
      expect((header! as AuthorizationBearer).token, equals('myToken123'));
      expect(header.encode(), equals(['Bearer myToken123']));
    });

    test('decodes Basic authentication credentials correctly', () {
      final header = AuthorizationHeader.decode([
        'Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==',
      ]);
      expect(header, isA<AuthorizationBasic>());
      final basic = header! as AuthorizationBasic;
      expect(basic.username, equals('Aladdin'));
      expect(basic.password, equals('open sesame'));
      expect(header.encode(), equals(['Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==']));
    });

    test('decodes custom authorization scheme correctly', () {
      final header = AuthorizationHeader.decode(['Digest abcdef']);
      expect(header, isA<AuthorizationCustom>());
      final custom = header! as AuthorizationCustom;
      expect(custom.scheme, equals('Digest'));
      expect(custom.value, equals('abcdef'));
      expect(header.encode(), equals(['Digest abcdef']));
    });

    test('returns null for invalid or empty values', () {
      expect(AuthorizationHeader.decode([]), isNull);
      expect(AuthorizationHeader.decode(['invalidNoSpace']), isNull);
      expect(AuthorizationHeader.decode(['Basic invalidBase64!!!']), isNull);
    });
  });
}

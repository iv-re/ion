import 'package:http_headers/src/headers/proxy_authorization.dart';
import 'package:test/test.dart';

void main() {
  group('ProxyAuthorizationHeader', () {
    test('decodes Basic authentication credentials correctly', () {
      final header = ProxyAuthorizationHeader.decode([
        'Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==',
      ]);
      expect(header, isA<ProxyAuthorizationBasic>());
      final basic = header! as ProxyAuthorizationBasic;
      expect(basic.username, equals('Aladdin'));
      expect(basic.password, equals('open sesame'));
      expect(header.encode(), equals(['Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==']));
    });

    test('returns null for invalid or empty values', () {
      expect(ProxyAuthorizationHeader.decode([]), isNull);
      expect(ProxyAuthorizationHeader.decode(['invalidNoSpace']), isNull);
    });
  });
}

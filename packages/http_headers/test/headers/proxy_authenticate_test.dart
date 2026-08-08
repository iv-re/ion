import 'package:http_headers/src/authentication_challenge.dart';
import 'package:http_headers/src/headers/proxy_authenticate.dart';
import 'package:test/test.dart';

void main() {
  group('ProxyAuthenticateHeader', () {
    test('decodes Basic correctly', () {
      final header = ProxyAuthenticateHeader.decode(['Basic realm="Proxy"']);
      expect(header, isNotNull);
      expect(header?.challenges, hasLength(1));

      final challenge =
          header!.challenges.first as AuthenticationChallengeBasic;
      expect(challenge.realm, equals('Proxy'));
      expect(challenge.charset, isNull);
      expect(header.encode(), equals(['Basic realm="Proxy"']));
    });

    test('decodes Bearer correctly', () {
      final header = ProxyAuthenticateHeader.decode([
        'Bearer realm="example", error="invalid_token"',
      ]);
      expect(header, isNotNull);
      expect(header?.challenges, hasLength(1));

      final challenge =
          header!.challenges.first as AuthenticationChallengeBearer;
      expect(challenge.realm, equals('example'));
      expect(challenge.error, equals('invalid_token'));
      expect(challenge.errorDescription, isNull);
      expect(
        header.encode(),
        equals(['Bearer realm="example", error="invalid_token"']),
      );
    });

    test('returns null for empty values', () {
      expect(ProxyAuthenticateHeader.decode([]), isNull);
      expect(ProxyAuthenticateHeader.decode(['   ']), isNull);
    });
  });
}

import 'package:http_headers/src/authentication_challenge.dart';
import 'package:http_headers/src/headers/www_authenticate.dart';
import 'package:test/test.dart';

void main() {
  group('WwwAuthenticateHeader', () {
    test('decodes Basic correctly', () {
      final header = WwwAuthenticateHeader.decode(['Basic realm="Access"']);
      expect(header, isNotNull);
      expect(header?.challenges, hasLength(1));

      final challenge =
          header!.challenges.first as AuthenticationChallengeBasic;
      expect(challenge.realm, equals('Access'));
      expect(challenge.charset, isNull);
      expect(header.encode(), equals(['Basic realm="Access"']));
    });

    test('decodes Basic with unquoted realm correctly', () {
      final header = WwwAuthenticateHeader.decode(['Basic realm=Access']);
      expect(header, isNotNull);
      expect(header?.challenges, hasLength(1));

      final challenge =
          header!.challenges.first as AuthenticationChallengeBasic;
      expect(challenge.realm, equals('Access'));
    });

    test('decodes Bearer correctly', () {
      final header = WwwAuthenticateHeader.decode([
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

    test('decodes custom correctly', () {
      final header = WwwAuthenticateHeader.decode([
        'Newauth realm="apps", type=1',
      ]);
      expect(header, isNotNull);
      expect(header?.challenges, hasLength(1));

      final challenge =
          header!.challenges.first as AuthenticationChallengeCustom;
      expect(challenge.scheme, equals('Newauth'));
      expect(challenge.parameters, equals('realm="apps", type=1'));
      expect(header.encode(), equals(['Newauth realm="apps", type=1']));
    });

    test('decodes multiple challenges correctly', () {
      final header = WwwAuthenticateHeader.decode([
        'Basic realm="a"',
        'Bearer realm="b"',
      ]);
      expect(header, isNotNull);
      expect(header?.challenges, hasLength(2));
      expect(header?.encode(), equals(['Basic realm="a"', 'Bearer realm="b"']));
    });

    test('returns null for empty values', () {
      expect(WwwAuthenticateHeader.decode([]), isNull);
      expect(WwwAuthenticateHeader.decode(['   ']), isNull);
    });
  });
}

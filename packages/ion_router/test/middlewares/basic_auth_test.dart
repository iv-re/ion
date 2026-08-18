import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:ion_router/ion_router.dart';
import 'package:ion_web/ion_web.dart';
import 'package:test/scaffolding.dart';

import 'utils.dart';

void main() {
  group('BasicAuth Middleware', () {
    test(
      'returns 401 Unauthorized with WWW-Authenticate header when '
      'no auth provided',
      () async {
        final app = IonRouter()
          ..use(Middlewares.basicAuth(credentials: {'admin': 'secret'}))
          ..get('/protected', (req) => Response.text('secret area'));

        final res = await makeRequest(app, path: '/protected');
        check(res).isA<Response>();
        check(res.status).equals(HttpStatusCode.unauthorized);

        final wwwAuthHeader = res.headers.firstWhere(
          (h) => h.name == 'WWW-Authenticate',
        );
        check(wwwAuthHeader.value).contains('Basic realm="Restricted"');
      },
    );

    test('authenticates valid credentials from credentials map', () async {
      final app = IonRouter()
        ..use(Middlewares.basicAuth(credentials: {'admin': 'secret123'}))
        ..get('/protected', (req) => Response.text('welcome admin'));

      final res = await makeRequest(
        app,
        path: '/protected',
        headers: [.authorization(.basic('admin', 'secret123'))],
      );

      check(res).isA<Response>();
      check(res.status).equals(HttpStatusCode.ok);
      check(res.body)
          .isA<BytesResponseBody>()
          .has(
            (b) => utf8.decode(b.bytes),
            'decoded bytes',
          )
          .equals('welcome admin');
    });

    test('rejects invalid password from credentials map', () async {
      final app = IonRouter()
        ..use(Middlewares.basicAuth(credentials: {'admin': 'secret123'}))
        ..get('/protected', (req) => Response.text('welcome admin'));

      final res = await makeRequest(
        app,
        path: '/protected',
        headers: [.authorization(.basic('admin', 'wrong_pass'))],
      );

      check(res).isA<Response>();
      check(res.status).equals(HttpStatusCode.unauthorized);
    });

    test('supports custom authenticator function', () async {
      final app = IonRouter()
        ..use(
          Middlewares.basicAuth(
            authenticator: (u, p) => u == 'john' && p == 'pass',
          ),
        )
        ..get('/protected', (req) {
          final auth = req.headers.authorization! as AuthorizationBasic;
          check(auth.username).equals('john');
          return Response.text('hello john');
        });

      final res = await makeRequest(
        app,
        path: '/protected',
        headers: [.authorization(.basic('john', 'pass'))],
      );

      check(res).isA<Response>();
      check(res.status).equals(HttpStatusCode.ok);
    });

    test(
      'throws AssertionError if neither credentials nor authenticator provided',
      () {
        check(Middlewares.basicAuth).throws<AssertionError>();
      },
    );
  });
}

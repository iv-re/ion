import 'package:ion_router/src/middleware.dart';
import 'package:ion_web/ion_web.dart';

/// Creates a [Middleware] for HTTP Basic Authentication.
///
/// Requires either [credentials] map (`username: password`) or a custom
/// [authenticator] function `(username, password)`.
Middleware basicAuthMiddleware({
  String realm = 'Restricted',
  Map<String, String>? credentials,
  bool Function(String username, String password)? authenticator,
}) {
  assert(
    credentials != null || authenticator != null,
    'basicAuth requires either credentials or authenticator to be specified.',
  );

  bool isValid(String username, String password) {
    if (authenticator != null) {
      return authenticator(username, password);
    }
    if (credentials != null) {
      final expectedPassword = credentials[username];
      if (expectedPassword == null) return false;
      return _constantTimeCompare(password, expectedPassword);
    }
    return false;
  }

  return (Handler next) {
    return (Request req) async {
      if (req.headers.authorization case AuthorizationBasic(
        :final username,
        :final password,
      ) when isValid(username, password)) {
        return next(req);
      }

      return .status(
        .unauthorized,
        headers: [
          .wwwAuthenticate([.basic(realm: realm)]),
        ],
      );
    };
  };
}

/// Constant time string comparison to prevent timing attacks.
bool _constantTimeCompare(String a, String b) {
  if (a.length != b.length) return false;
  var result = 0;
  for (var i = 0; i < a.length; i++) {
    result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return result == 0;
}

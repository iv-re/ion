import 'package:http_headers/src/authentication_challenge.dart';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Proxy-Authenticate` response header field,
/// defined in [RFC 9110 Section 11.6.3](https://datatracker.ietf.org/doc/html/rfc9110#section-11.6.3).
///
/// Consists of at least one challenge that indicates the authentication
/// scheme(s) and parameters applicable to the proxy.
///
/// ```dart
/// final header = ProxyAuthenticateHeader([
///   AuthenticationChallenge.basic(realm: 'Proxy Access'),
/// ]);
/// final decoded = ProxyAuthenticateHeader.decode([
///   'Basic realm="Proxy Access"'
/// ]);
/// ```
final class ProxyAuthenticateHeader implements TypedHeader {
  /// Creates a `Proxy-Authenticate` header with a list of challenges.
  const ProxyAuthenticateHeader(this.challenges);

  /// Decodes this header type from raw header values.
  static ProxyAuthenticateHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;

    final challenges = <AuthenticationChallenge>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        final challenge = AuthenticationChallenge.parse(trimmed);
        if (challenge != null) {
          challenges.add(challenge);
        }
      }
    }

    if (challenges.isEmpty) return null;
    return ProxyAuthenticateHeader(challenges);
  }

  /// The list of authentication challenges.
  final List<AuthenticationChallenge> challenges;

  @override
  String get name => HttpHeader.proxyAuthenticate.name;

  @override
  Iterable<String> encode() => challenges.map((c) => c.toString());

  @override
  String toString() => 'ProxyAuthenticateHeader(${challenges.join(', ')})';
}

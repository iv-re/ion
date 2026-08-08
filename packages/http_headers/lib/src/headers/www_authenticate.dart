import 'package:http_headers/src/authentication_challenge.dart';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `WWW-Authenticate` response header field,
/// defined in [RFC 9110 Section 11.6.1](https://datatracker.ietf.org/doc/html/rfc9110#section-11.6.1).
///
/// Indicates the authentication scheme(s) and parameters applicable to the
/// target resource.
///
/// ```dart
/// final header = WwwAuthenticateHeader([
///   AuthenticationChallenge.basic(realm: 'Access to staging'),
/// ]);
/// final decoded = WwwAuthenticateHeader.decode([
///   'Basic realm="Access to staging"'
/// ]);
/// ```
final class WwwAuthenticateHeader implements TypedHeader {
  /// Creates a `WWW-Authenticate` header with a list of challenges.
  const WwwAuthenticateHeader(this.challenges);

  /// Decodes this header type from raw header values.
  static WwwAuthenticateHeader? decode(Iterable<String> values) {
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
    return WwwAuthenticateHeader(challenges);
  }

  /// The list of authentication challenges.
  final List<AuthenticationChallenge> challenges;

  @override
  String get name => HttpHeader.wwwAuthenticate.name;

  @override
  Iterable<String> encode() => challenges.map((c) => c.toString());

  @override
  String toString() => 'WwwAuthenticateHeader(${challenges.join(', ')})';
}

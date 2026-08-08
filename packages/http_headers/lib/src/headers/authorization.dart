import 'dart:convert';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Authorization` request header field,
/// defined in [RFC 7235 Section 4.2](https://datatracker.ietf.org/doc/html/rfc7235#section-4.2).
///
/// Allows user agent to authenticate itself with an origin server.
///
/// ```dart
/// final basic = AuthorizationHeader.basic('Aladdin', 'open sesame');
/// final bearer = AuthorizationHeader.bearer('fpKL54jvWmEGVoRdCNjG');
/// final decoded =
///     AuthorizationHeader.decode(['Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==']);
/// ```
sealed class AuthorizationHeader implements TypedHeader {
  /// Creates a `Basic` authorization header with username and password.
  factory AuthorizationHeader.basic(
    String username,
    String password,
  ) = AuthorizationBasic;

  /// Creates a `Bearer` authorization header with bearer token string.
  const factory AuthorizationHeader.bearer(
    String token,
  ) = AuthorizationBearer;

  /// Creates an `Authorization` header with custom scheme and value string.
  const factory AuthorizationHeader.custom(
    String scheme,
    String value,
  ) = AuthorizationCustom;

  /// Decodes this header type from raw header values.
  static AuthorizationHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (raw.isEmpty) return null;

    final spaceIdx = raw.indexOf(' ');
    if (spaceIdx == -1) return null;

    final scheme = raw.substring(0, spaceIdx).trim();
    final valuePart = raw.substring(spaceIdx + 1).trimLeft();

    if (scheme.toLowerCase() == 'basic') {
      try {
        final decodedBytes = base64.decode(valuePart);
        final decodedStr = utf8.decode(decodedBytes);
        final colonIdx = decodedStr.indexOf(':');
        if (colonIdx != -1) {
          final user = decodedStr.substring(0, colonIdx);
          final pass = decodedStr.substring(colonIdx + 1);
          return AuthorizationBasic(user, pass);
        }
      } catch (_) {
        return null;
      }
    } else if (scheme.toLowerCase() == 'bearer') {
      return AuthorizationBearer(valuePart);
    }

    return AuthorizationCustom(scheme, valuePart);
  }

  @override
  String get name => HttpHeader.authorization.name;
}

/// Public class representing `Basic` authentication credentials.
final class AuthorizationBasic implements AuthorizationHeader {
  AuthorizationBasic(this.username, this.password);

  final String username;
  final String password;

  @override
  String get name => HttpHeader.authorization.name;

  @override
  Iterable<String> encode() {
    final credentials = '$username:$password';
    final encoded = base64.encode(utf8.encode(credentials));
    return ['Basic $encoded'];
  }

  @override
  String toString() => 'AuthorizationHeader.basic($username)';
}

/// Public class representing `Bearer` authentication credentials token.
final class AuthorizationBearer implements AuthorizationHeader {
  const AuthorizationBearer(this.token);

  final String token;

  @override
  String get name => HttpHeader.authorization.name;

  @override
  Iterable<String> encode() => ['Bearer $token'];

  @override
  String toString() => 'AuthorizationHeader.bearer($token)';
}

/// Public class representing custom authorization scheme and credentials.
final class AuthorizationCustom implements AuthorizationHeader {
  const AuthorizationCustom(this.scheme, this.value);

  final String scheme;
  final String value;

  @override
  String get name => HttpHeader.authorization.name;

  @override
  Iterable<String> encode() => ['$scheme $value'];

  @override
  String toString() => 'AuthorizationHeader.custom($scheme $value)';
}

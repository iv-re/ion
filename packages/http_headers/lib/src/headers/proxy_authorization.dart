import 'dart:convert';

import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/headers/authorization.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Proxy-Authorization` request header field,
/// defined in [RFC 7235 Section 4.4](https://datatracker.ietf.org/doc/html/rfc7235#section-4.4).
///
/// Allows user agent to authenticate itself with an HTTP proxy.
///
/// ```dart
/// final basic = ProxyAuthorizationHeader.basic('Aladdin', 'open sesame');
/// final decoded =
///     ProxyAuthorizationHeader.decode(['Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==']);
/// ```
sealed class ProxyAuthorizationHeader implements TypedHeader {
  /// Creates a `Basic` proxy authorization header.
  factory ProxyAuthorizationHeader.basic(String username, String password) =
      ProxyAuthorizationBasic;

  /// Creates a `Bearer` proxy authorization header.
  const factory ProxyAuthorizationHeader.bearer(String token) =
      ProxyAuthorizationBearer;

  /// Creates a `Proxy-Authorization` header with custom scheme and credentials.
  const factory ProxyAuthorizationHeader.custom(String scheme, String value) =
      ProxyAuthorizationCustom;

  /// Decodes this header type from raw header values.
  static ProxyAuthorizationHeader? decode(Iterable<String> values) {
    final auth = AuthorizationHeader.decode(values);
    if (auth == null) return null;
    return switch (auth) {
      AuthorizationBasic(:final username, :final password) =>
        ProxyAuthorizationBasic(username, password),
      AuthorizationBearer(:final token) => ProxyAuthorizationBearer(token),
      AuthorizationCustom(:final scheme, :final value) =>
        ProxyAuthorizationCustom(scheme, value),
    };
  }

  @override
  String get name => HttpHeader.proxyAuthorization.name;
}

/// Public class representing `Proxy-Authorization` with Basic credentials.
final class ProxyAuthorizationBasic implements ProxyAuthorizationHeader {
  ProxyAuthorizationBasic(this.username, this.password);

  final String username;
  final String password;

  @override
  String get name => HttpHeader.proxyAuthorization.name;

  @override
  Iterable<String> encode() {
    final credentials = '$username:$password';
    final encoded = base64.encode(utf8.encode(credentials));
    return ['Basic $encoded'];
  }

  @override
  String toString() => 'ProxyAuthorizationHeader.basic($username)';
}

/// Public class representing `Proxy-Authorization` with Bearer token.
final class ProxyAuthorizationBearer implements ProxyAuthorizationHeader {
  const ProxyAuthorizationBearer(this.token);

  final String token;

  @override
  String get name => HttpHeader.proxyAuthorization.name;

  @override
  Iterable<String> encode() => ['Bearer $token'];

  @override
  String toString() => 'ProxyAuthorizationHeader.bearer($token)';
}

/// Public class representing custom `Proxy-Authorization` scheme.
final class ProxyAuthorizationCustom implements ProxyAuthorizationHeader {
  const ProxyAuthorizationCustom(this.scheme, this.value);

  final String scheme;
  final String value;

  @override
  String get name => HttpHeader.proxyAuthorization.name;

  @override
  Iterable<String> encode() => ['$scheme $value'];

  @override
  String toString() => 'ProxyAuthorizationHeader.custom($scheme $value)';
}

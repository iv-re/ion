import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Set-Cookie` response header field,
/// defined in [RFC 6265 Section 4.1](https://datatracker.ietf.org/doc/html/rfc6265#section-4.1).
///
/// Sends cookies from server to user agent.
///
/// ```dart
/// final setCookie = SetCookieHeader.fromCookie(
///   Cookie('SID', '31d4d96e407aad42')..path = '/',
/// );
/// final decoded = SetCookieHeader.decode(['foo=bar; Path=/']);
/// ```
final class SetCookieHeader extends Equatable implements TypedHeader {
  /// Creates a `Set-Cookie` header with a list of [Cookie] objects.
  const SetCookieHeader(this.cookies);

  /// Creates a `Set-Cookie` header with a single [Cookie].
  SetCookieHeader.fromCookie(Cookie cookie) : cookies = [cookie];

  /// Decodes this header type from raw header values.
  static SetCookieHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final cookies = <Cookie>[];
    for (final val in values) {
      final trimmed = val.trim();
      if (trimmed.isEmpty) continue;
      try {
        cookies.add(Cookie.fromSetCookieValue(trimmed));
      } catch (_) {
        // Skip malformed cookie strings
      }
    }
    if (cookies.isEmpty) return null;
    return SetCookieHeader(cookies);
  }

  /// List of [Cookie] instances.
  final List<Cookie> cookies;

  @override
  String get name => HttpHeader.setCookie.name;

  @override
  Iterable<String> encode() => cookies.map((c) => c.toString()).toList();

  @override
  List<Object?> get props => [cookies];
}

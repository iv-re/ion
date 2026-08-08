import 'package:equatable/equatable.dart';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Cookie` request header field,
/// defined in [RFC 6265 Section 5.4](https://datatracker.ietf.org/doc/html/rfc6265#section-5.4).
///
/// Contains stored HTTP cookies for origin server.
///
/// ```dart
/// const cookie = CookieHeader({'SID': '31d4d96e407aad42', 'lang': 'en-US'});
/// final decoded = CookieHeader.decode(['SID=31d4d96e407aad42; lang=en-US']);
/// ```
final class CookieHeader extends Equatable implements TypedHeader {
  /// Creates a `Cookie` header with map of cookie key-value pairs.
  const CookieHeader(this.cookies);

  /// Decodes this header type from raw header values.
  ///
  /// Limits the total number of parsed cookie pairs to [maxCookies]
  static CookieHeader? decode(
    Iterable<String> values, {
    int maxCookies = 3000,
  }) {
    if (values.isEmpty) return null;
    final map = <String, String>{};

    parseValues:
    for (final raw in values) {
      if (raw.trim().isEmpty) continue;
      final parts = raw.split(';');
      for (final part in parts) {
        if (map.length >= maxCookies) break parseValues;
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        final eqIdx = trimmed.indexOf('=');
        if (eqIdx != -1) {
          final key = trimmed.substring(0, eqIdx).trim();
          final val = trimmed.substring(eqIdx + 1).trim();
          if (key.isNotEmpty && !map.containsKey(key)) {
            map[key] = val;
          }
        }
      }
    }
    if (map.isEmpty && values.every((v) => v.trim().isEmpty)) return null;
    return CookieHeader(map);
  }

  /// Map of cookie key-value pairs.
  final Map<String, String> cookies;

  @override
  String get name => HttpHeader.cookie.name;

  /// Number of cookie key-value pairs.
  int get length => cookies.length;

  /// Returns the cookie value for [name], or `null` if absent.
  String? operator [](String name) => cookies[name];

  /// Returns the cookie value for [name], or `null` if absent.
  String? get(String name) => cookies[name];

  @override
  Iterable<String> encode() {
    if (cookies.isEmpty) return [];
    final pairs = cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    return [pairs];
  }

  @override
  List<Object?> get props => [cookies];
}

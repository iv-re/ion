import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Pragma` HTTP/1.0 header field,
/// defined in [RFC 7234 Section 5.4](https://datatracker.ietf.org/doc/html/rfc7234#section-5.4).
///
/// Backwards compatibility header for HTTP/1.0 caches.
///
/// ```dart
/// const pragma = PragmaHeader.noCache();
/// final decoded = PragmaHeader.decode(['no-cache']);
/// ```
final class PragmaHeader implements TypedHeader {
  /// Creates a `Pragma` header with a custom string value.
  const PragmaHeader(this.value);

  /// Creates a `Pragma: no-cache` header.
  const PragmaHeader.noCache() : value = 'no-cache';

  /// Decodes this header type from raw header values.
  static PragmaHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (raw.isEmpty) return null;
    if (raw.toLowerCase() == 'no-cache') return const PragmaHeader.noCache();
    return PragmaHeader(raw);
  }

  /// Raw header value string.
  final String value;

  @override
  String get name => HttpHeader.pragma.name;

  /// Returns `true` if this pragma is `no-cache`.
  bool get isNoCache => value.trim().toLowerCase() == 'no-cache';

  @override
  Iterable<String> encode() => [value];

  @override
  String toString() => 'PragmaHeader($value)';
}

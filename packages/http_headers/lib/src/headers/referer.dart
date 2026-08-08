import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Referer` request header field,
/// defined in [RFC 7231 Section 5.5.2](https://datatracker.ietf.org/doc/html/rfc7231#section-5.5.2).
///
/// Specifies URI reference for resource from which target URI was obtained.
///
/// ```dart
/// const ref = RefererHeader('/People.html#tim');
/// final decoded = RefererHeader.decode(['http://www.example.org/hypertext/Overview.html']);
/// ```
final class RefererHeader implements TypedHeader {
  /// Creates a `Referer` header with the given URI string.
  const RefererHeader(this.uri);

  /// Decodes this header type from raw header values.
  static RefererHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (raw.isEmpty) return null;
    return RefererHeader(raw);
  }

  /// The URI reference string.
  final String uri;

  @override
  String get name => HttpHeader.referer.name;

  @override
  Iterable<String> encode() => [uri];

  @override
  String toString() => 'RefererHeader($uri)';
}

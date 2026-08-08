import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Content-Location` header field,
/// defined in [RFC 7231 Section 3.1.4.2](https://datatracker.ietf.org/doc/html/rfc7231#section-3.1.4.2).
///
/// Refers to the URI for the representation enclosed in the payload.
///
/// ```dart
/// const loc = ContentLocationHeader('/hypertext/Overview.html');
/// final decoded = ContentLocationHeader.decode(['http://www.example.org/index.html']);
/// ```
final class ContentLocationHeader implements TypedHeader {
  /// Creates a `Content-Location` header with the given URI string.
  const ContentLocationHeader(this.uri);

  /// Decodes this header type from raw header values.
  static ContentLocationHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (raw.isEmpty) return null;
    return ContentLocationHeader(raw);
  }

  /// The URI string representation.
  final String uri;

  @override
  String get name => HttpHeader.contentLocation.name;

  @override
  Iterable<String> encode() => [uri];

  @override
  String toString() => 'ContentLocationHeader($uri)';
}

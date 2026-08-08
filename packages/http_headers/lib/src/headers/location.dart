import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Location` response header field,
/// defined in [RFC 7231 Section 7.1.2](https://datatracker.ietf.org/doc/html/rfc7231#section-7.1.2).
///
/// Refers to a specific resource in relation to the response (redirect or
/// created resource).
///
/// ```dart
/// const loc = LocationHeader('/People.html#tim');
/// final decoded = LocationHeader.decode(['http://www.example.net/index.html']);
/// ```
final class LocationHeader implements TypedHeader {
  /// Creates a `Location` header with the target URI reference string.
  const LocationHeader(this.uri);

  /// Decodes this header type from raw header values.
  static LocationHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (raw.isEmpty) return null;
    return LocationHeader(raw);
  }

  /// Target URI string reference.
  final String uri;

  @override
  String get name => HttpHeader.location.name;

  @override
  Iterable<String> encode() => [uri];

  @override
  String toString() => 'LocationHeader($uri)';
}

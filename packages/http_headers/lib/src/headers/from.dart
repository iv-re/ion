import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `From` request header field,
/// defined in [RFC 9110 Section 10.1.2](https://datatracker.ietf.org/doc/html/rfc9110#section-10.1.2).
///
/// Contains an Internet email address for a human user who controls the
/// requesting user agent.
///
/// ```dart
/// final from = FromHeader('webmaster@example.org');
/// final decoded = FromHeader.decode(['webmaster@example.org']);
/// ```
final class FromHeader implements TypedHeader {
  /// Creates a `From` header with the given email address.
  const FromHeader(this.email);

  /// Decodes this header type from raw header values.
  static FromHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (raw.isEmpty) return null;
    return FromHeader(raw);
  }

  /// The internet email address.
  final String email;

  @override
  String get name => HttpHeader.from.name;

  @override
  Iterable<String> encode() => [email];

  @override
  String toString() => 'FromHeader($email)';
}

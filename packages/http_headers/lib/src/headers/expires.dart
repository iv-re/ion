import 'dart:io';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Expires` response header field,
/// defined in [RFC 7234 Section 5.3](https://datatracker.ietf.org/doc/html/rfc7234#section-5.3).
///
/// Gives the date/time after which the response is considered stale.
///
/// ```dart
/// final expires = ExpiresHeader(DateTime.now().add(Duration(hours: 1)));
/// final decoded = ExpiresHeader.decode(['Thu, 01 Dec 1994 16:00:00 GMT']);
/// ```
final class ExpiresHeader implements TypedHeader {
  /// Creates an `Expires` header with the given expiration date.
  const ExpiresHeader(this.date);

  /// Decodes this header type from raw header values.
  static ExpiresHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;

    try {
      return ExpiresHeader(HttpDate.parse(values.first));
    } catch (_) {
      return null;
    }
  }

  /// Expiration timestamp.
  final DateTime date;

  @override
  String get name => HttpHeader.expires.name;

  @override
  Iterable<String> encode() => [HttpDate.format(date)];

  @override
  String toString() => 'ExpiresHeader(${HttpDate.format(date)})';
}

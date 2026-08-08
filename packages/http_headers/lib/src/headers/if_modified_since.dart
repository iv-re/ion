import 'dart:io';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `If-Modified-Since` request header field,
/// defined in [RFC 7232 Section 3.3](https://datatracker.ietf.org/doc/html/rfc7232#section-3.3).
///
/// Makes GET/HEAD request conditional on resource modification date.
///
/// ```dart
/// final ifMod = IfModifiedSinceHeader(
///   DateTime.now().subtract(Duration(days: 1)),
/// );
/// final decoded =
///     IfModifiedSinceHeader.decode(['Sat, 29 Oct 1994 19:43:31 GMT']);
/// ```
final class IfModifiedSinceHeader implements TypedHeader {
  /// Creates an `If-Modified-Since` header with the given timestamp.
  const IfModifiedSinceHeader(this.date);

  /// Decodes this header type from raw header values.
  static IfModifiedSinceHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    try {
      final dt = HttpDate.parse(values.first.trim());
      return IfModifiedSinceHeader(dt);
    } catch (_) {
      return null;
    }
  }

  /// Timestamp date value.
  final DateTime date;

  @override
  String get name => HttpHeader.ifModifiedSince.name;

  /// Returns `true` if resource modified timestamp is newer than this header's
  /// date.
  bool isModified(DateTime lastModified) {
    return date.isBefore(lastModified);
  }

  @override
  Iterable<String> encode() => [HttpDate.format(date)];

  @override
  String toString() => 'IfModifiedSinceHeader(${HttpDate.format(date)})';
}

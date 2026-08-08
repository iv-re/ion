import 'dart:io';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `If-Unmodified-Since` request header field,
/// defined in [RFC 7232 Section 3.4](https://datatracker.ietf.org/doc/html/rfc7232#section-3.4).
///
/// Makes request conditional on resource modification date being earlier/equal.
///
/// ```dart
/// final ifUnmod = IfUnmodifiedSinceHeader(
///   DateTime.now().subtract(Duration(days: 1)),
/// );
/// final decoded =
///     IfUnmodifiedSinceHeader.decode(['Sat, 29 Oct 1994 19:43:31 GMT']);
/// ```
final class IfUnmodifiedSinceHeader implements TypedHeader {
  /// Creates an `If-Unmodified-Since` header with the given timestamp.
  const IfUnmodifiedSinceHeader(this.date);

  /// Decodes this header type from raw header values.
  static IfUnmodifiedSinceHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    try {
      final dt = HttpDate.parse(values.first.trim());
      return IfUnmodifiedSinceHeader(dt);
    } catch (_) {
      return null;
    }
  }

  /// Timestamp date value.
  final DateTime date;

  @override
  String get name => HttpHeader.ifUnmodifiedSince.name;

  /// Checks if precondition passes for resource last modified timestamp.
  bool preconditionPasses(DateTime lastModified) {
    return date.isAfter(lastModified) || date.isAtSameMomentAs(lastModified);
  }

  @override
  Iterable<String> encode() => [HttpDate.format(date)];

  @override
  String toString() => 'IfUnmodifiedSinceHeader(${HttpDate.format(date)})';
}

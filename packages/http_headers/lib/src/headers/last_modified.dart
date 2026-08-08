import 'dart:io';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Last-Modified` response header field,
/// defined in [RFC 7232 Section 2.2](https://datatracker.ietf.org/doc/html/rfc7232#section-2.2).
///
/// Timestamp indicating date and time when origin server believes resource was
/// last modified.
///
/// ```dart
/// final lastMod = LastModifiedHeader(DateTime.now());
/// final decoded =
///     LastModifiedHeader.decode(['Sat, 29 Oct 1994 19:43:31 GMT']);
/// ```
final class LastModifiedHeader implements TypedHeader {
  /// Creates a `Last-Modified` header with the given timestamp.
  const LastModifiedHeader(this.date);

  /// Decodes this header type from raw header values.
  static LastModifiedHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    try {
      final dt = HttpDate.parse(values.first.trim());
      return LastModifiedHeader(dt);
    } catch (_) {
      return null;
    }
  }

  /// Modification timestamp date.
  final DateTime date;

  @override
  String get name => HttpHeader.lastModified.name;

  @override
  Iterable<String> encode() => [HttpDate.format(date)];

  @override
  String toString() => 'LastModifiedHeader(${HttpDate.format(date)})';
}

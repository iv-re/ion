import 'dart:io';

import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Date` header field,
/// defined in [RFC 7231 Section 7.1.1.2](https://datatracker.ietf.org/doc/html/rfc7231#section-7.1.1.2).
///
/// Represents the date and time at which the message was originated.
///
/// ```dart
/// final date = DateHeader(DateTime.now());
/// final decoded = DateHeader.decode(['Tue, 15 Nov 1994 08:12:31 GMT']);
/// ```
final class DateHeader implements TypedHeader {
  /// Creates a `Date` header with message origin timestamp.
  const DateHeader(this.date);

  /// Decodes this header type from raw header values.
  static DateHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    try {
      final dt = HttpDate.parse(values.first.trim());
      return DateHeader(dt);
    } catch (_) {
      return null;
    }
  }

  /// Timestamp date value.
  final DateTime date;

  @override
  String get name => HttpHeader.date.name;

  @override
  Iterable<String> encode() => [HttpDate.format(date)];

  @override
  String toString() => 'DateHeader(${HttpDate.format(date)})';
}

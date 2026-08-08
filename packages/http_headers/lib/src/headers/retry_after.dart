import 'dart:io';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Retry-After` response header field,
/// defined in [RFC 7231 Section 7.1.3](https://datatracker.ietf.org/doc/html/rfc7231#section-7.1.3).
///
/// Indicates minimum time client is asked to wait before issuing request.
///
/// ```dart
/// final delay = RetryAfterHeader.delay(Duration(seconds: 300));
/// final date = RetryAfterHeader.date(DateTime.now());
/// final decoded = RetryAfterHeader.decode(['1234']);
/// ```
sealed class RetryAfterHeader implements TypedHeader {
  /// Creates a `Retry-After` header with a delay [Duration].
  const factory RetryAfterHeader.delay(Duration duration) = RetryAfterDelay;

  /// Creates a `Retry-After` header with an HTTP [DateTime].
  const factory RetryAfterHeader.date(DateTime date) = RetryAfterDate;

  /// Decodes this header type from raw header values.
  static RetryAfterHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    final secs = int.tryParse(raw);
    if (secs != null && secs >= 0) {
      return RetryAfterDelay(Duration(seconds: secs));
    }
    try {
      final dt = HttpDate.parse(raw);
      return RetryAfterDate(dt);
    } catch (_) {
      return null;
    }
  }

  @override
  String get name => HttpHeader.retryAfter.name;
}

/// Public class representing `Retry-After` with a delay duration.
final class RetryAfterDelay implements RetryAfterHeader {
  const RetryAfterDelay(this.duration);

  final Duration duration;

  @override
  String get name => HttpHeader.retryAfter.name;

  @override
  Iterable<String> encode() => [duration.inSeconds.toString()];

  @override
  String toString() => 'RetryAfterHeader.delay(${duration.inSeconds}s)';
}

/// Public class representing `Retry-After` with an HTTP timestamp.
final class RetryAfterDate implements RetryAfterHeader {
  const RetryAfterDate(this.date);

  final DateTime date;

  @override
  String get name => HttpHeader.retryAfter.name;

  @override
  Iterable<String> encode() => [HttpDate.format(date)];

  @override
  String toString() => 'RetryAfterHeader.date(${HttpDate.format(date)})';
}

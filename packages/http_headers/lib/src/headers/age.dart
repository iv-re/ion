import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Age` response header field,
/// defined in [RFC 7234 Section 5.1](https://datatracker.ietf.org/doc/html/rfc7234#section-5.1).
///
/// Conveys sender's estimate of time since response was generated at origin
/// server.
///
/// ```dart
/// final age = AgeHeader.fromSeconds(60);
/// final decoded = AgeHeader.decode(['3600']);
/// ```
final class AgeHeader implements TypedHeader {
  /// Creates an `Age` header with the given duration.
  const AgeHeader(this.duration);

  /// Creates an `Age` header from a number of whole seconds.
  AgeHeader.fromSeconds(int seconds) : duration = Duration(seconds: seconds);

  /// Decodes this header type from raw header values.
  static AgeHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    final seconds = int.tryParse(raw);
    if (seconds == null || seconds < 0) return null;
    return AgeHeader.fromSeconds(seconds);
  }

  /// Age duration.
  final Duration duration;

  @override
  String get name => HttpHeader.age.name;

  @override
  Iterable<String> encode() => [duration.inSeconds.toString()];

  @override
  String toString() => 'AgeHeader(${duration.inSeconds}s)';
}

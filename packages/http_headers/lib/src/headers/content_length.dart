import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';
import 'package:http_headers/src/util.dart';

/// The `Content-Length` header field,
/// defined in [RFC 7230 Section 3.3.2](https://datatracker.ietf.org/doc/html/rfc7230#section-3.3.2).
///
/// Provides the anticipated payload body size in decimal number of octets.
///
/// ```dart
/// const len = ContentLengthHeader(1000);
/// final decoded = ContentLengthHeader.decode(['1000']);
/// ```
final class ContentLengthHeader implements TypedHeader {
  /// Creates a `Content-Length` header with the length in bytes.
  const ContentLengthHeader(this.bytes);

  /// Decodes this header type from raw header values.
  ///
  /// If multiple `Content-Length` values are provided, they must all be valid
  /// and equal.
  static ContentLengthHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    int? length;
    for (final val in values) {
      final raw = val.trim();
      if (!isAsciiDigits(raw)) return null;
      final parsed = int.tryParse(raw);
      if (parsed == null || parsed < 0) return null;
      if (length != null && length != parsed) return null;
      length = parsed;
    }
    if (length == null) return null;
    return ContentLengthHeader(length);
  }

  /// Payload size in bytes.
  final int bytes;

  @override
  String get name => HttpHeader.contentLength.name;

  /// Alias getter for [bytes].
  int get length => bytes;

  @override
  Iterable<String> encode() {
    return [bytes.toString()];
  }

  @override
  String toString() => 'ContentLengthHeader($bytes)';
}

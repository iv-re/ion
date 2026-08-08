import 'package:equatable/equatable.dart';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/http_range.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Range` request header field,
/// defined in [RFC 7233 Section 3.1](https://datatracker.ietf.org/doc/html/rfc7233#section-3.1).
///
/// Modifies GET request semantics to request transfer of subranges of
/// representation data.
///
/// ```dart
/// final range = RangeHeader.bytes(0, 499);
/// final decoded = RangeHeader.decode(['bytes=1000-2000']);
/// ```
final class RangeHeader extends Equatable implements TypedHeader {
  /// Creates a `Range` header with raw range string (e.g. `bytes=0-499`).
  const RangeHeader(this.raw);

  /// Creates a `Range: bytes=<start>-<end>` header.
  factory RangeHeader.bytes(int start, [int? end]) {
    final sb = StringBuffer('bytes=$start-');
    if (end != null) {
      sb.write(end);
    }
    return RangeHeader(sb.toString());
  }

  /// Decodes this header type from raw header values.
  static RangeHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (!raw.startsWith('bytes=')) return null;
    return RangeHeader(raw);
  }

  final String raw;

  /// Parses satisfiable ranges given resource total length per RFC 7233 §2.1.
  List<HttpRange> ranges(int contentLength) {
    return HttpRange.parse(raw, contentLength);
  }

  @override
  String get name => HttpHeader.range.name;

  @override
  List<Object?> get props => [raw];

  @override
  Iterable<String> encode() => [raw];
}

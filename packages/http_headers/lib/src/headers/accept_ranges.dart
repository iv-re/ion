import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Accept-Ranges` response header field,
/// defined in [RFC 7233 Section 2.3](https://datatracker.ietf.org/doc/html/rfc7233#section-2.3).
///
/// Allows a server to indicate that it supports range requests.
///
/// ```dart
/// const bytesRanges = AcceptRangesHeader.bytes();
/// const noRanges = AcceptRangesHeader.none();
/// final decoded = AcceptRangesHeader.decode(['bytes']);
/// ```
final class AcceptRangesHeader implements TypedHeader {
  /// Creates an `Accept-Ranges` header with a custom range unit.
  const AcceptRangesHeader(this.rangeUnit);

  /// Creates an `Accept-Ranges: bytes` header.
  const AcceptRangesHeader.bytes() : rangeUnit = 'bytes';

  /// Creates an `Accept-Ranges: none` header.
  const AcceptRangesHeader.none() : rangeUnit = 'none';

  /// Decodes this header type from raw header values.
  static AcceptRangesHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (raw.isEmpty) return null;
    if (raw == 'bytes') return const AcceptRangesHeader.bytes();
    if (raw == 'none') return const AcceptRangesHeader.none();
    return AcceptRangesHeader(raw);
  }

  /// The range unit string (e.g. `bytes`, `none`).
  final String rangeUnit;

  @override
  String get name => HttpHeader.acceptRanges.name;

  /// Returns `true` if range unit is `bytes`.
  bool get isBytes => rangeUnit.toLowerCase() == 'bytes';

  /// Returns `true` if range unit is `none`.
  bool get isNone => rangeUnit.toLowerCase() == 'none';

  @override
  Iterable<String> encode() => [rangeUnit];

  @override
  String toString() => 'AcceptRangesHeader($rangeUnit)';
}

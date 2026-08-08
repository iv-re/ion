import 'package:equatable/equatable.dart';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Content-Range` header field,
/// defined in [RFC 7233 Section 4.2](https://datatracker.ietf.org/doc/html/rfc7233#section-4.2).
///
/// Sent with a partial message body to specify where the body fits within
/// full body.
///
/// ```dart
/// final cr = ContentRangeHeader.bytes(100, 199, 3400);
/// final unsatisfied = ContentRangeHeader.unsatisfiedBytes(3400);
/// final decoded = ContentRangeHeader.decode(['bytes 0-499/500']);
/// ```
final class ContentRangeHeader extends Equatable implements TypedHeader {
  /// Creates a `Content-Range` header with raw fields.
  const ContentRangeHeader(this.start, this.end, [this.completeLength]);

  /// Creates a `Content-Range: bytes <first>-<last>/<completeLength>` header.
  const ContentRangeHeader.bytes(
    int this.start,
    int this.end, [
    this.completeLength,
  ]);

  /// Creates an unsatisfied `Content-Range: bytes */<completeLength>` header.
  const ContentRangeHeader.unsatisfiedBytes(int this.completeLength)
    : start = null,
      end = null;

  /// Decodes this header type from raw header values.
  static ContentRangeHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (!raw.startsWith('bytes ')) return null;
    final spec = raw.substring('bytes '.length).trim();

    final slashIdx = spec.indexOf('/');
    if (slashIdx == -1) return null;

    final rangePart = spec.substring(0, slashIdx).trim();
    final lenPart = spec.substring(slashIdx + 1).trim();

    int? compLen;
    if (lenPart != '*') {
      compLen = int.tryParse(lenPart);
      if (compLen == null || compLen < 0) return null;
    }

    if (rangePart == '*') {
      if (compLen == null) return null;
      return ContentRangeHeader.unsatisfiedBytes(compLen);
    }

    final dashIdx = rangePart.indexOf('-');
    if (dashIdx == -1) return null;

    final firstStr = rangePart.substring(0, dashIdx).trim();
    final lastStr = rangePart.substring(dashIdx + 1).trim();

    final first = int.tryParse(firstStr);
    final last = int.tryParse(lastStr);
    if (first == null || last == null || first < 0 || last < first) {
      return null;
    }

    return ContentRangeHeader(first, last, compLen);
  }

  /// First byte index (inclusive), or `null` if unsatisfied range.
  final int? start;

  /// Last byte index (inclusive), or `null` if unsatisfied range.
  final int? end;

  /// Complete length of the resource in bytes, or `null` if unknown.
  final int? completeLength;

  @override
  String get name => HttpHeader.contentRange.name;

  /// Returns `(start, end)` tuple if satisfiable byte range is specified.
  (int, int)? get bytesRange {
    return (start != null && end != null) ? (start!, end!) : null;
  }

  /// Complete byte length if known.
  int? get bytesLen => completeLength;

  @override
  Iterable<String> encode() {
    final sb = StringBuffer('bytes ');
    if (start != null && end != null) {
      sb.write('$start-$end');
    } else {
      sb.write('*');
    }
    sb.write('/');
    if (completeLength != null) {
      sb.write(completeLength);
    } else {
      sb.write('*');
    }
    return [sb.toString()];
  }

  @override
  List<Object?> get props => [start, end, completeLength];
}

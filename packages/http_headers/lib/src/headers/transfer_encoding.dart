import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';
import 'package:http_headers/src/util.dart';

/// An individual transfer coding (e.g. chunked, gzip, compress, deflate).
extension type const TransferCoding(String value) implements String {
  /// `chunked`
  static const chunked = TransferCoding('chunked');

  /// `gzip`
  static const gzip = TransferCoding('gzip');

  /// `deflate`
  static const deflate = TransferCoding('deflate');

  /// `compress`
  static const compress = TransferCoding('compress');

  /// `identity`
  static const identity = TransferCoding('identity');

  /// Whether this transfer coding is `chunked`.
  bool get isChunked => value == 'chunked';
}

/// The `Transfer-Encoding` header field,
/// defined in [RFC 7230 Section 3.3.1](https://datatracker.ietf.org/doc/html/rfc7230#section-3.3.1).
///
/// Lists the transfer coding names applied to payload body.
///
/// ```dart
/// const chunked = TransferEncodingHeader.chunked();
/// final decoded = TransferEncodingHeader.decode(['gzip, chunked']);
/// ```
final class TransferEncodingHeader implements TypedHeader {
  /// Creates a `Transfer-Encoding` header with specified transfer codings.
  const TransferEncodingHeader(this.codings);

  /// Creates a `Transfer-Encoding: chunked` header.
  const TransferEncodingHeader.chunked() : codings = const [.chunked];

  /// Decodes this header type from raw header values.
  static TransferEncodingHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final items = parseCsv(values)
        .map((part) => TransferCoding(part.trim().toLowerCase()))
        .where((c) => c.isNotEmpty)
        .toList();
    if (items.isEmpty && values.every((v) => v.trim().isEmpty)) return null;
    return TransferEncodingHeader(items);
  }

  /// List of transfer codings applied.
  final List<TransferCoding> codings;

  @override
  String get name => HttpHeader.transferEncoding.name;

  /// Returns `true` if the final coding in this header is `chunked`.
  bool get isChunked {
    if (codings.isEmpty) return false;
    return codings.last.isChunked;
  }

  /// Returns `true` if `chunked` is included anywhere in [codings].
  bool get hasChunked => codings.any((c) => c.isChunked);

  /// Returns `true` if `chunked` is present but is NOT the final transfer
  /// coding, indicating a potential HTTP Request Smuggling conflict
  /// (RFC 7230 Section 3.3.3).
  bool get hasNonFinalChunkedConflict => hasChunked && !isChunked;

  /// Returns `true` if this Transfer-Encoding header configuration is valid.
  bool get isValid => !hasNonFinalChunkedConflict;

  @override
  Iterable<String> encode() {
    if (codings.isEmpty) return const [];
    return [codings.map((c) => c.value).join(', ')];
  }

  @override
  String toString() => 'TransferEncodingHeader($codings)';
}

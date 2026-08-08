import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';
import 'package:http_headers/src/util.dart';

/// The `Content-Encoding` header field,
/// defined in [RFC 7231 Section 3.1.2.2](https://datatracker.ietf.org/doc/html/rfc7231#section-3.1.2.2).
///
/// Indicates what content codings have been applied to the representation.
///
/// ```dart
/// const encGzip = ContentEncodingHeader.gzip();
/// const encBr = ContentEncodingHeader.brotli();
/// final decoded = ContentEncodingHeader.decode(['gzip, br']);
/// ```
final class ContentEncodingHeader implements TypedHeader {
  /// Creates a `Content-Encoding` header with custom codings list.
  const ContentEncodingHeader(this.codings);

  /// Creates a `Content-Encoding: gzip` header.
  const ContentEncodingHeader.gzip() : codings = const ['gzip'];

  /// Creates a `Content-Encoding: br` header.
  const ContentEncodingHeader.brotli() : codings = const ['br'];

  /// Creates a `Content-Encoding: zstd` header.
  const ContentEncodingHeader.zstd() : codings = const ['zstd'];

  /// Decodes this header type from raw header values.
  static ContentEncodingHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final items = parseCsv(values).toList();
    if (items.isEmpty && values.every((v) => v.trim().isEmpty)) return null;
    return ContentEncodingHeader(items);
  }

  /// List of content codings applied.
  final List<String> codings;

  @override
  String get name => HttpHeader.contentEncoding.name;

  /// Returns `true` if this header contains the given content coding.
  bool contains(String coding) {
    final search = coding.trim().toLowerCase();
    return codings.any((c) => c.trim().toLowerCase() == search);
  }

  @override
  Iterable<String> encode() {
    return codings.isNotEmpty ? [codings.join(', ')] : const [];
  }

  @override
  String toString() => 'ContentEncodingHeader($codings)';
}

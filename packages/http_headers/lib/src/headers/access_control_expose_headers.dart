import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';
import 'package:http_headers/src/util.dart';

/// The `Access-Control-Expose-Headers` response header,
/// part of [CORS](https://fetch.spec.whatwg.org/#http-access-control-expose-headers).
///
/// Indicates which headers are safe to expose to the API of a CORS
/// specification.
///
/// ```dart
/// final expose =
///     AccessControlExposeHeadersHeader(['content-length', 'etag']);
/// final decoded =
///     AccessControlExposeHeadersHeader.decode(['ETag, Content-Length']);
/// ```
final class AccessControlExposeHeadersHeader implements TypedHeader {
  /// Creates an `Access-Control-Expose-Headers` header with the given list of
  /// header names.
  const AccessControlExposeHeadersHeader(this.headers);

  /// Decodes this header type from raw header values.
  static AccessControlExposeHeadersHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final items = parseCsv(values).toList();
    if (items.isEmpty && values.every((v) => v.trim().isEmpty)) return null;
    return AccessControlExposeHeadersHeader(items);
  }

  /// List of exposed header field names.
  final List<String> headers;

  @override
  String get name => HttpHeader.accessControlExposeHeaders.name;

  @override
  Iterable<String> encode() {
    if (headers.isEmpty) return const [];
    return [headers.join(', ')];
  }

  @override
  String toString() => 'AccessControlExposeHeadersHeader($headers)';
}

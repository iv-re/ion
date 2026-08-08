import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';
import 'package:http_headers/src/util.dart';

/// The `Access-Control-Request-Headers` request header,
/// part of [CORS](https://fetch.spec.whatwg.org/#http-access-control-request-headers).
///
/// Indicates which headers will be used in the actual request as part of a
/// preflight request.
///
/// ```dart
/// final reqHeaders =
///     AccessControlRequestHeadersHeader(['accept-language', 'date']);
/// final decoded =
///     AccessControlRequestHeadersHeader.decode(['accept-language, date']);
/// ```
final class AccessControlRequestHeadersHeader implements TypedHeader {
  /// Creates an `Access-Control-Request-Headers` header with the given list of
  /// header names.
  const AccessControlRequestHeadersHeader(this.headers);

  /// Decodes this header type from raw header values.
  static AccessControlRequestHeadersHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final items = parseCsv(values).toList();
    if (items.isEmpty && values.every((v) => v.trim().isEmpty)) return null;
    return AccessControlRequestHeadersHeader(items);
  }

  /// List of request header field names.
  final List<String> headers;

  @override
  String get name => HttpHeader.accessControlRequestHeaders.name;

  @override
  Iterable<String> encode() {
    if (headers.isEmpty) return const [];
    return [headers.join(', ')];
  }

  @override
  String toString() => 'AccessControlRequestHeadersHeader($headers)';
}

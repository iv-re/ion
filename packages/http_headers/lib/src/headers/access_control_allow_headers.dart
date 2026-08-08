import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';
import 'package:http_headers/src/util.dart';

/// The `Access-Control-Allow-Headers` response header,
/// part of [CORS](https://fetch.spec.whatwg.org/#http-access-control-allow-headers).
///
/// Indicates which header field names can be used during the actual request.
///
/// ```dart
/// final allowHeaders =
///     AccessControlAllowHeadersHeader(['accept-language', 'date']);
/// final decoded =
///     AccessControlAllowHeadersHeader.decode(['accept-language, date']);
/// ```
final class AccessControlAllowHeadersHeader implements TypedHeader {
  /// Creates an `Access-Control-Allow-Headers` header with the given list of
  /// header names.
  const AccessControlAllowHeadersHeader(this.headers);

  /// Decodes this header type from raw header values.
  static AccessControlAllowHeadersHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final items = parseCsv(values).toList();
    if (items.isEmpty && values.every((v) => v.trim().isEmpty)) return null;
    return AccessControlAllowHeadersHeader(items);
  }

  /// List of allowed header field names.
  final List<String> headers;

  @override
  String get name => HttpHeader.accessControlAllowHeaders.name;

  @override
  Iterable<String> encode() {
    if (headers.isEmpty) return const [];
    return [headers.join(', ')];
  }

  @override
  String toString() => 'AccessControlAllowHeadersHeader($headers)';
}

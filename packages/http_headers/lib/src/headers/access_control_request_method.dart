import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Access-Control-Request-Method` request header,
/// part of [CORS](https://fetch.spec.whatwg.org/#http-access-control-request-method).
///
/// Indicates which HTTP method will be used in the actual request as part of a
/// preflight request.
///
/// ```dart
/// final reqMethod = AccessControlRequestMethodHeader('GET');
/// final decoded = AccessControlRequestMethodHeader.decode(['GET']);
/// ```
final class AccessControlRequestMethodHeader implements TypedHeader {
  /// Creates an `Access-Control-Request-Method` header with the given HTTP
  /// method.
  const AccessControlRequestMethodHeader(this.method);

  /// Decodes this header type from raw header values.
  static AccessControlRequestMethodHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (raw.isEmpty) return null;
    return AccessControlRequestMethodHeader(raw);
  }

  /// The HTTP method.
  final String method;

  @override
  String get name => HttpHeader.accessControlRequestMethod.name;

  @override
  Iterable<String> encode() => [method];

  @override
  String toString() => 'AccessControlRequestMethodHeader($method)';
}

import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';
import 'package:http_headers/src/util.dart';

/// The `Access-Control-Allow-Methods` response header,
/// part of [CORS](https://fetch.spec.whatwg.org/#http-access-control-allow-methods).
///
/// Indicates which HTTP methods can be used during the actual request.
///
/// ```dart
/// final allowMethods =
///     AccessControlAllowMethodsHeader(['GET', 'POST']);
/// final decoded = AccessControlAllowMethodsHeader.decode(['GET, PUT']);
/// ```
final class AccessControlAllowMethodsHeader implements TypedHeader {
  /// Creates an `Access-Control-Allow-Methods` header with the given list of
  /// allowed HTTP methods.
  const AccessControlAllowMethodsHeader(this.methods);

  /// Decodes this header type from raw header values.
  static AccessControlAllowMethodsHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final items = parseCsv(values).toList();
    if (items.isEmpty && values.every((v) => v.trim().isEmpty)) return null;
    return AccessControlAllowMethodsHeader(items);
  }

  /// List of allowed HTTP methods.
  final List<String> methods;

  @override
  String get name => HttpHeader.accessControlAllowMethods.name;

  @override
  Iterable<String> encode() {
    if (methods.isEmpty) return const [];
    return [methods.join(', ')];
  }

  @override
  String toString() => 'AccessControlAllowMethodsHeader($methods)';
}

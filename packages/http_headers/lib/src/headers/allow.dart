import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';
import 'package:http_headers/src/util.dart';

/// The `Allow` response header field,
/// defined in [RFC 7231 Section 7.4.1](https://datatracker.ietf.org/doc/html/rfc7231#section-7.4.1).
///
/// Lists the set of HTTP methods advertised as supported by the target
/// resource.
///
/// ```dart
/// final allow = AllowHeader(['GET', 'POST']);
/// final decoded = AllowHeader.decode(['GET, HEAD, PUT']);
/// ```
final class AllowHeader implements TypedHeader {
  /// Creates an `Allow` header with the given list of allowed HTTP methods.
  const AllowHeader(this.methods);

  /// Decodes this header type from raw header values.
  static AllowHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final items = parseCsv(values).toList();
    if (items.isEmpty && values.every((v) => v.trim().isEmpty)) return null;
    return AllowHeader(items);
  }

  /// List of allowed HTTP methods.
  final List<String> methods;

  @override
  String get name => HttpHeader.allow.name;

  @override
  Iterable<String> encode() {
    if (methods.isEmpty) return const [];
    return [methods.join(', ')];
  }

  @override
  String toString() => 'AllowHeader($methods)';
}

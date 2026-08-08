import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';
import 'package:http_headers/src/util.dart';

/// The `Vary` response header field,
/// defined in [RFC 7231 Section 7.1.4](https://datatracker.ietf.org/doc/html/rfc7231#section-7.1.4).
///
/// Describes what parts of request message might influence origin server's
/// response selection.
///
/// ```dart
/// const anyVary = VaryHeader.any();
/// final headersVary = VaryHeader(['accept-encoding', 'accept-language']);
/// final decoded = VaryHeader.decode(['accept-encoding, accept-language']);
/// ```
final class VaryHeader implements TypedHeader {
  /// Creates a `Vary` header with a list of header field names.
  const VaryHeader(this.headers);

  /// Creates a `Vary: *` header.
  const VaryHeader.any() : headers = const ['*'];

  /// Decodes this header type from raw header values.
  static VaryHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final items = parseCsv(values).toList();
    if (items.isEmpty && values.every((v) => v.trim().isEmpty)) return null;
    return VaryHeader(items);
  }

  /// List of header field names (or `['*']`).
  final List<String> headers;

  @override
  String get name => HttpHeader.vary.name;

  /// Returns `true` if wildcard `*` is included.
  bool get isAny => headers.any((h) => h.trim() == '*');

  /// Returns an iterable over header name strings.
  Iterable<String> iterStrs() => headers;

  @override
  Iterable<String> encode() {
    if (headers.isEmpty) return const [];
    return [headers.join(', ')];
  }

  @override
  String toString() => 'VaryHeader($headers)';
}

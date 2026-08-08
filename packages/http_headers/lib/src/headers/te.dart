import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';
import 'package:http_headers/src/util.dart';

/// The `TE` request header field,
/// defined in [RFC 7230 Section 4.3](https://datatracker.ietf.org/doc/html/rfc7230#section-4.3).
///
/// Indicates what transfer codings the client is willing to accept in response.
///
/// ```dart
/// const teTrailers = TeHeader.trailers();
/// final decoded = TeHeader.decode(['trailers, deflate;q=0.5']);
/// ```
final class TeHeader implements TypedHeader {
  /// Creates a `TE` header with the given list of codings.
  const TeHeader(this.codings);

  /// Creates a `TE: trailers` header.
  const TeHeader.trailers() : codings = const ['trailers'];

  /// Decodes this header type from raw header values.
  static TeHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final items = parseCsv(values).toList();
    if (items.isEmpty && values.every((v) => v.trim().isEmpty)) return null;
    return TeHeader(items);
  }

  /// List of acceptable transfer coding specifications.
  final List<String> codings;

  @override
  String get name => HttpHeader.te.name;

  @override
  Iterable<String> encode() {
    if (codings.isEmpty) return const [];
    return [codings.join(', ')];
  }

  @override
  String toString() => 'TeHeader($codings)';
}

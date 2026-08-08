import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Max-Forwards` request header field,
/// defined in [RFC 9110 Section 10.1.3](https://datatracker.ietf.org/doc/html/rfc9110#section-10.1.3).
///
/// Provides a mechanism with the TRACE and OPTIONS methods to limit the number
/// of times that the request is forwarded by proxies.
///
/// ```dart
/// final maxForwards = MaxForwardsHeader(10);
/// final decoded = MaxForwardsHeader.decode(['10']);
/// ```
final class MaxForwardsHeader implements TypedHeader {
  /// Creates a `Max-Forwards` header with the given count.
  const MaxForwardsHeader(this.count);

  /// Decodes this header type from raw header values.
  static MaxForwardsHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    final count = int.tryParse(raw);
    if (count == null || count < 0) return null;
    return MaxForwardsHeader(count);
  }

  /// The remaining number of times this request message can be forwarded.
  final int count;

  @override
  String get name => HttpHeader.maxForwards.name;

  @override
  Iterable<String> encode() => [count.toString()];

  @override
  String toString() => 'MaxForwardsHeader($count)';
}

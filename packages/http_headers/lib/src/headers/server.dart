import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Server` response header field,
/// defined in [RFC 7231 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc7231#section-7.4.2).
///
/// Contains information about software used by origin server.
///
/// ```dart
/// const server = ServerHeader('CERN/3.0 libwww/2.17');
/// final decoded = ServerHeader.decode(['hyper/0.12.2']);
/// ```
final class ServerHeader implements TypedHeader {
  /// Creates a `Server` header with software details string.
  const ServerHeader(this.value);

  /// Decodes this header type from raw header values.
  static ServerHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (raw.isEmpty) return null;
    return ServerHeader(raw);
  }

  /// Software details string.
  final String value;

  @override
  String get name => HttpHeader.server.name;

  @override
  Iterable<String> encode() => [value];

  @override
  String toString() => 'ServerHeader($value)';
}

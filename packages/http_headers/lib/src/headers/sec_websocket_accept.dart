import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Sec-WebSocket-Accept` response header field,
/// defined in [RFC 6455 Section 4.2.2](https://datatracker.ietf.org/doc/html/rfc6455#section-4.2.2).
///
/// Returned by server in WebSocket handshake indicating successful handshake.
///
/// ```dart
/// const accept = SecWebSocketAcceptHeader('s3pPLMBiTxaQ9kYGzzhZRbK+xOo=');
/// final decoded =
///     SecWebSocketAcceptHeader.decode(['s3pPLMBiTxaQ9kYGzzhZRbK+xOo=']);
/// ```
final class SecWebSocketAcceptHeader implements TypedHeader {
  /// Creates a `Sec-WebSocket-Accept` header with the base64 accept string
  /// value.
  const SecWebSocketAcceptHeader(this.value);

  /// Decodes this header type from raw header values.
  static SecWebSocketAcceptHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (raw.isEmpty) return null;
    return SecWebSocketAcceptHeader(raw);
  }

  /// Base64 accept value string.
  final String value;

  @override
  String get name => HttpHeader.secWebSocketAccept.name;

  @override
  Iterable<String> encode() => [value];

  @override
  String toString() => 'SecWebSocketAcceptHeader($value)';
}

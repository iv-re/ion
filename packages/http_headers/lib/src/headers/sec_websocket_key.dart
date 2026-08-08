import 'dart:convert';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Sec-WebSocket-Key` request header field,
/// defined in [RFC 6455 Section 4.1](https://datatracker.ietf.org/doc/html/rfc6455#section-4.1).
///
/// Sent by client in WebSocket handshake request.
///
/// ```dart
/// final key = SecWebSocketKeyHeader.fromBytes(
///   [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
/// );
/// final decoded = SecWebSocketKeyHeader.decode(['dGhlIHNhbXBsZSBub25jZQ==']);
/// ```
final class SecWebSocketKeyHeader implements TypedHeader {
  /// Creates a `Sec-WebSocket-Key` header with base64 key string value.
  const SecWebSocketKeyHeader(this.value);

  /// Creates a `Sec-WebSocket-Key` header from 16 raw bytes base64-encoded.
  factory SecWebSocketKeyHeader.fromBytes(List<int> bytes) {
    return SecWebSocketKeyHeader(base64.encode(bytes));
  }

  /// Decodes this header type from raw header values.
  static SecWebSocketKeyHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (raw.isEmpty) return null;
    return SecWebSocketKeyHeader(raw);
  }

  /// Base64-encoded key string value.
  final String value;

  @override
  String get name => HttpHeader.secWebSocketKey.name;

  /// Alias getter for [value].
  String get key => value;

  @override
  Iterable<String> encode() => [value];

  @override
  String toString() => 'SecWebSocketKeyHeader($value)';
}

import 'package:equatable/equatable.dart';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';
import 'package:http_headers/src/util.dart';

/// The `Sec-WebSocket-Protocol` header field,
/// defined in [RFC 6455 Section 4.3](https://datatracker.ietf.org/doc/html/rfc6455#section-4.3).
///
/// Indicates subprotocols requested by client or selected by server.
///
/// ```dart
/// const proto = SecWebSocketProtocolHeader(['chat', 'superchat']);
/// final decoded = SecWebSocketProtocolHeader.decode(['chat, superchat']);
/// ```
final class SecWebSocketProtocolHeader extends Equatable
    implements TypedHeader {
  /// Creates a `Sec-WebSocket-Protocol` header with a list of subprotocol
  /// names.
  const SecWebSocketProtocolHeader(this.protocols);

  /// Creates a `Sec-WebSocket-Protocol` header with a single subprotocol name.
  SecWebSocketProtocolHeader.single(String protocol) : protocols = [protocol];

  /// Decodes this header type from raw header values.
  static SecWebSocketProtocolHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final items = parseCsv(values).toList();
    if (items.isEmpty && values.every((v) => v.trim().isEmpty)) return null;
    return SecWebSocketProtocolHeader(items);
  }

  /// List of subprotocol names.
  final List<String> protocols;

  @override
  String get name => HttpHeader.secWebSocketProtocol.name;

  @override
  Iterable<String> encode() {
    if (protocols.isEmpty) return const [];
    return [protocols.join(', ')];
  }

  @override
  List<Object?> get props => [protocols];

  @override
  String toString() => 'SecWebSocketProtocolHeader($protocols)';
}

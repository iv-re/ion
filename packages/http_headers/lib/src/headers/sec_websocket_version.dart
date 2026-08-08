import 'package:equatable/equatable.dart';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Sec-WebSocket-Version` header field,
/// defined in [RFC 6455 Section 4.4](https://datatracker.ietf.org/doc/html/rfc6455#section-4.4).
///
/// Specifies the WebSocket protocol version.
///
/// ```dart
/// const v13 = SecWebSocketVersionHeader.v13();
/// final decoded = SecWebSocketVersionHeader.decode(['13']);
/// ```
final class SecWebSocketVersionHeader extends Equatable implements TypedHeader {
  /// Creates a `Sec-WebSocket-Version` header with the given version integer.
  const SecWebSocketVersionHeader(this.version);

  /// Creates a `Sec-WebSocket-Version: 13` header.
  const SecWebSocketVersionHeader.v13() : version = 13;

  /// Decodes this header type from raw header values.
  static SecWebSocketVersionHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    final parsed = int.tryParse(raw);
    if (parsed == null) return null;
    if (parsed == 13) return const SecWebSocketVersionHeader.v13();
    return SecWebSocketVersionHeader(parsed);
  }

  /// The WebSocket version number.
  final int version;

  @override
  String get name => HttpHeader.secWebSocketVersion.name;

  @override
  Iterable<String> encode() => [version.toString()];

  @override
  List<Object?> get props => [version];
}

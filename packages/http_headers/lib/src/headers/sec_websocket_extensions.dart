import 'package:equatable/equatable.dart';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';
import 'package:http_headers/src/util.dart';

/// The `Sec-WebSocket-Extensions` header field,
/// defined in [RFC 6455 Section 9.1](https://datatracker.ietf.org/doc/html/rfc6455#section-9.1).
///
/// Requests or confirms WebSocket extensions (e.g. permessage-deflate).
///
/// ```dart
/// const ext = SecWebSocketExtensionsHeader(
///   perMessageDeflate: true,
///   clientNoContextTakeover: true,
/// );
/// final decoded = SecWebSocketExtensionsHeader.decode([
///   'permessage-deflate; client_no_context_takeover',
/// ]);
/// ```
final class SecWebSocketExtensionsHeader extends Equatable
    implements TypedHeader {
  /// Creates a `Sec-WebSocket-Extensions` header.
  const SecWebSocketExtensionsHeader({
    this.perMessageDeflate = false,
    this.clientNoContextTakeover = false,
    this.serverNoContextTakeover = false,
    this.customExtensions = const [],
  });

  /// Decodes this header type from raw header values.
  static SecWebSocketExtensionsHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final items = parseCsv(values).toList();
    if (items.isEmpty && values.every((v) => v.trim().isEmpty)) return null;

    var perMessageDeflate = false;
    var clientNoContextTakeover = false;
    var serverNoContextTakeover = false;
    final custom = <String>[];

    for (final item in items) {
      final parts = item.split(';').map((s) => s.trim()).toList();
      for (final part in parts) {
        if (part == 'permessage-deflate') {
          perMessageDeflate = true;
        } else if (part == 'client_no_context_takeover') {
          clientNoContextTakeover = true;
        } else if (part == 'server_no_context_takeover') {
          serverNoContextTakeover = true;
        } else if (part.isNotEmpty) {
          custom.add(part);
        }
      }
    }

    return SecWebSocketExtensionsHeader(
      perMessageDeflate: perMessageDeflate,
      clientNoContextTakeover: clientNoContextTakeover,
      serverNoContextTakeover: serverNoContextTakeover,
      customExtensions: custom,
    );
  }

  /// Whether permessage-deflate is enabled.
  final bool perMessageDeflate;

  /// Whether client_no_context_takeover parameter is present.
  final bool clientNoContextTakeover;

  /// Whether server_no_context_takeover parameter is present.
  final bool serverNoContextTakeover;

  /// Additional raw extension tokens or parameters.
  final List<String> customExtensions;

  @override
  String get name => HttpHeader.secWebSocketExtensions.name;

  @override
  Iterable<String> encode() {
    final parts = <String>[];
    if (perMessageDeflate) parts.add('permessage-deflate');
    if (clientNoContextTakeover) parts.add('client_no_context_takeover');
    if (serverNoContextTakeover) parts.add('server_no_context_takeover');
    parts.addAll(customExtensions);
    if (parts.isEmpty) return const [];
    return [parts.join('; ')];
  }

  @override
  List<Object?> get props => [
    perMessageDeflate,
    clientNoContextTakeover,
    serverNoContextTakeover,
    customExtensions,
  ];

  @override
  String toString() =>
      'SecWebSocketExtensionsHeader(perMessageDeflate: $perMessageDeflate, '
      'clientNoContextTakeover: $clientNoContextTakeover, '
      'serverNoContextTakeover: $serverNoContextTakeover, '
      'customExtensions: $customExtensions)';
}

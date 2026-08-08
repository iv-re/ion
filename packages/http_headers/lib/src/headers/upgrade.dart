import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';
import 'package:http_headers/src/util.dart';

/// The `Upgrade` header field,
/// defined in [RFC 7230 Section 6.7](https://datatracker.ietf.org/doc/html/rfc7230#section-6.7).
///
/// Provides mechanism for transitioning from HTTP/1.1 to another protocol on same connection.
///
/// ```dart
/// const ws = UpgradeHeader.websocket();
/// final decoded = UpgradeHeader.decode(['websocket']);
/// ```
final class UpgradeHeader implements TypedHeader {
  /// Creates an `Upgrade` header with a list of protocol names.
  const UpgradeHeader(this.protocols);

  /// Creates an `Upgrade: websocket` header.
  const UpgradeHeader.websocket() : protocols = const ['websocket'];

  /// Decodes this header type from raw header values.
  static UpgradeHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final items = parseCsv(values).toList();
    if (items.isEmpty && values.every((v) => v.trim().isEmpty)) return null;
    return UpgradeHeader(items);
  }

  /// List of protocols to upgrade to.
  final List<String> protocols;

  @override
  String get name => HttpHeader.upgrade.name;

  @override
  Iterable<String> encode() {
    if (protocols.isEmpty) return const [];
    return [protocols.join(', ')];
  }

  @override
  String toString() => 'UpgradeHeader($protocols)';
}

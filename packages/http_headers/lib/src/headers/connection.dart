import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';
import 'package:http_headers/src/util.dart';

/// The `Connection` header field,
/// defined in [RFC 7230 Section 6.1](https://datatracker.ietf.org/doc/html/rfc7230#section-6.1).
///
/// Indicates desired control options for the current connection.
///
/// ```dart
/// const connClose = ConnectionHeader.close();
/// const connKeepAlive = ConnectionHeader.keepAlive();
/// final decoded = ConnectionHeader.decode(['keep-alive']);
/// ```
final class ConnectionHeader implements TypedHeader {
  /// Creates a `Connection` header with custom connection options.
  const ConnectionHeader(this.options);

  /// Creates a `Connection: close` header.
  const ConnectionHeader.close() : options = const ['close'];

  /// Creates a `Connection: keep-alive` header.
  const ConnectionHeader.keepAlive() : options = const ['keep-alive'];

  /// Creates a `Connection: upgrade` header.
  const ConnectionHeader.upgrade() : options = const ['upgrade'];

  /// Decodes this header type from raw header values.
  static ConnectionHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final items = parseCsv(values).toList();
    if (items.isEmpty && values.every((v) => v.trim().isEmpty)) return null;
    return ConnectionHeader(items);
  }

  /// List of connection option tokens.
  final List<String> options;

  @override
  String get name => HttpHeader.connection.name;

  /// Returns `true` if this header contains the given connection option
  /// (case-insensitive).
  bool contains(String option) {
    final search = option.trim().toLowerCase();
    return options.any((opt) => opt.trim().toLowerCase() == search);
  }

  /// Returns `true` if this contains `close`.
  bool get isClose => contains('close');

  /// Returns `true` if this contains `keep-alive`.
  bool get isKeepAlive => contains('keep-alive');

  /// Returns `true` if this contains `upgrade`.
  bool get isUpgrade => contains('upgrade');

  @override
  Iterable<String> encode() {
    if (options.isEmpty) return const [];
    return [options.join(', ')];
  }

  @override
  String toString() => 'ConnectionHeader($options)';
}

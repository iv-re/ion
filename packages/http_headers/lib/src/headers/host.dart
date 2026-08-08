import 'package:equatable/equatable.dart';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Host` request header field,
/// defined in [RFC 7230 Section 5.4](https://datatracker.ietf.org/doc/html/rfc7230#section-5.4).
///
/// Specifies the host and port number of the server being requested.
///
/// ```dart
/// final host = HostHeader('example.com:8080');
/// final decoded = HostHeader.decode(['example.com:8080']);
/// ```
final class HostHeader extends Equatable implements TypedHeader {
  /// Creates a `Host` header with raw value (e.g. `example.com:8080`).
  const HostHeader(this.value);

  /// Decodes this header type from raw header values.
  ///
  /// According to RFC 7230 Section 5.4, a request MUST NOT contain
  /// more than one Host header field.
  static HostHeader? decode(Iterable<String> values) {
    if (values.isEmpty || values.length > 1) return null;
    final trimmed = values.first.trim();
    final header = HostHeader(trimmed);
    if (!header.isValid) return null;
    return header;
  }

  /// The raw value of the Host header.
  final String value;

  /// The hostname or IP address (without port).
  String get host {
    final colonIndex = value.lastIndexOf(':');
    if (colonIndex != -1 && !value.endsWith(']')) {
      return value.substring(0, colonIndex);
    }
    return value;
  }

  /// The optional port number.
  int? get port {
    final colonIndex = value.lastIndexOf(':');
    if (colonIndex != -1 && !value.endsWith(']')) {
      return int.tryParse(value.substring(colonIndex + 1));
    }
    return null;
  }

  @override
  String get name => HttpHeader.host.name;

  /// Whether the host header value format is valid.
  bool get isValid {
    final h = host;
    if (h.isEmpty || h.contains('@') || h.contains('/')) return false;
    final colonIndex = value.lastIndexOf(':');
    if (colonIndex != -1 && !value.endsWith(']')) {
      return int.tryParse(value.substring(colonIndex + 1)) != null;
    }
    return true;
  }

  @override
  Iterable<String> encode() => [value];

  @override
  List<Object?> get props => [value];
}

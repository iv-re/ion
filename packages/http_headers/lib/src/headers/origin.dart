import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Origin` request header field,
/// defined in [Fetch Specification](https://fetch.spec.whatwg.org/#origin-header).
///
/// Indicates where a request originated from.
///
/// ```dart
/// const nullOrigin = OriginHeader.nullOrigin();
/// final origin = OriginHeader.parts('https', 'example.com', 8000);
/// final decoded = OriginHeader.decode(['http://web-platform.test:8000']);
/// ```
sealed class OriginHeader implements TypedHeader {
  /// `Origin: null`
  const factory OriginHeader.nullOrigin() = OriginNull;

  /// Creates an `Origin: <scheme>://<host>[:<port>]` header.
  factory OriginHeader.parts(String scheme, String host, [int? port]) =
      OriginValue.parts;

  /// Decodes this header type from raw header values.
  static OriginHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (raw == 'null') {
      return const OriginNull();
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    return OriginValue(raw);
  }

  @override
  String get name => HttpHeader.origin.name;

  /// Returns `true` if this origin is `null`.
  bool get isNull;

  /// Scheme string (e.g. `http`, `https`), or empty string if `null`.
  String get scheme;

  /// Host string, or empty string if `null`.
  String get host;

  /// Hostname string (alias for [host]), or empty string if `null`.
  String get hostname;

  /// Port number if specified, or `null`.
  int? get port;
}

/// Class representing `Origin: null`.
final class OriginNull implements OriginHeader {
  /// Creates a `null` origin header.
  const OriginNull();

  @override
  String get name => HttpHeader.origin.name;

  @override
  Iterable<String> encode() => const ['null'];

  @override
  bool get isNull => true;

  @override
  String get scheme => '';

  @override
  String get host => '';

  @override
  String get hostname => '';

  @override
  int? get port => null;

  @override
  String toString() => 'OriginHeader.nullOrigin()';
}

/// Class representing a non-null origin value.
final class OriginValue implements OriginHeader {
  /// Creates an `OriginValue` with the raw string representation.
  const OriginValue(this.value);

  /// Creates an `OriginValue` from scheme, host, and optional port.
  factory OriginValue.parts(String scheme, String host, [int? port]) {
    final sb = StringBuffer('$scheme://$host');
    if (port != null) {
      sb.write(':$port');
    }
    return OriginValue(sb.toString());
  }

  /// The raw origin URL string value.
  final String value;

  @override
  String get name => HttpHeader.origin.name;

  @override
  Iterable<String> encode() => [value];

  @override
  bool get isNull => false;

  @override
  String get scheme {
    final idx = value.indexOf('://');
    if (idx != -1) return value.substring(0, idx);
    return '';
  }

  @override
  String get host {
    final uri = Uri.tryParse(value);
    return uri?.host ?? '';
  }

  @override
  String get hostname => host;

  @override
  int? get port {
    final uri = Uri.tryParse(value);
    return uri?.hasPort == true ? uri?.port : null;
  }

  @override
  String toString() => 'OriginHeader($value)';
}

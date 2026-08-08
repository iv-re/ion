import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Access-Control-Allow-Origin` response header,
/// part of [CORS](https://fetch.spec.whatwg.org/#http-access-control-allow-origin).
///
/// The `Access-Control-Allow-Origin` header indicates whether a resource
/// can be shared by returning the value of the Origin request header,
/// `*`, or `null` in the response.
///
/// ```dart
/// const anyOrigin = AccessControlAllowOriginHeader.any();
/// const nullOrigin = AccessControlAllowOriginHeader.nullOrigin();
/// final origin = AccessControlAllowOriginHeader.origin('https://example.com');
/// final decoded = AccessControlAllowOriginHeader.decode(['https://example.com']);
/// ```
sealed class AccessControlAllowOriginHeader implements TypedHeader {
  /// `Access-Control-Allow-Origin: *`
  const factory AccessControlAllowOriginHeader.any() =
      AccessControlAllowOriginAny;

  /// `Access-Control-Allow-Origin: null`
  const factory AccessControlAllowOriginHeader.nullOrigin() =
      AccessControlAllowOriginNull;

  /// `Access-Control-Allow-Origin: <origin>`
  const factory AccessControlAllowOriginHeader.origin(String origin) =
      AccessControlAllowOriginValue;

  /// Decodes this header type from raw header values.
  static AccessControlAllowOriginHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (raw.isEmpty) return null;
    if (raw == '*') {
      return const AccessControlAllowOriginAny();
    }
    if (raw == 'null') {
      return const AccessControlAllowOriginNull();
    }
    return AccessControlAllowOriginValue(raw);
  }

  /// Returns `true` if the origin is `*`.
  bool get isAny;

  /// Returns `true` if the origin is `null`.
  bool get isNull;

  /// Returns the origin string if specified, or `null` if it is `*` or `null`.
  String? get origin;

  @override
  String get name => HttpHeader.accessControlAllowOrigin.name;
}

/// Wildcard origin (`*`).
final class AccessControlAllowOriginAny
    implements AccessControlAllowOriginHeader {
  /// Creates a wildcard origin header.
  const AccessControlAllowOriginAny();

  @override
  String get name => HttpHeader.accessControlAllowOrigin.name;

  @override
  Iterable<String> encode() => const ['*'];

  @override
  bool get isAny => true;

  @override
  bool get isNull => false;

  @override
  String? get origin => null;

  @override
  String toString() => 'AccessControlAllowOriginHeader.any()';
}

/// Null origin (`null`).
final class AccessControlAllowOriginNull
    implements AccessControlAllowOriginHeader {
  /// Creates a null origin header.
  const AccessControlAllowOriginNull();

  @override
  String get name => HttpHeader.accessControlAllowOrigin.name;

  @override
  Iterable<String> encode() => const ['null'];

  @override
  bool get isAny => false;

  @override
  bool get isNull => true;

  @override
  String? get origin => null;

  @override
  String toString() => 'AccessControlAllowOriginHeader.nullOrigin()';
}

/// Specific origin value string.
final class AccessControlAllowOriginValue
    implements AccessControlAllowOriginHeader {
  /// Creates an origin header with specified origin value string.
  const AccessControlAllowOriginValue(this.value);

  /// The origin string value.
  final String value;

  @override
  String get name => HttpHeader.accessControlAllowOrigin.name;

  @override
  Iterable<String> encode() => [value];

  @override
  bool get isAny => false;

  @override
  bool get isNull => false;

  @override
  String? get origin => value;

  @override
  String toString() => 'AccessControlAllowOriginHeader.origin($value)';
}

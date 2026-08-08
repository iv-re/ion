import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Access-Control-Max-Age` response header,
/// part of [CORS](https://fetch.spec.whatwg.org/#http-access-control-max-age).
///
/// Indicates how long the results of a preflight request can be cached.
///
/// ```dart
/// final maxAge = AccessControlMaxAgeHeader(Duration(seconds: 531));
/// final decoded = AccessControlMaxAgeHeader.decode(['531']);
/// ```
final class AccessControlMaxAgeHeader implements TypedHeader {
  /// Creates an `Access-Control-Max-Age` header with the given duration.
  const AccessControlMaxAgeHeader(this.duration);

  /// Decodes this header type from raw header values.
  static AccessControlMaxAgeHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    final secs = int.tryParse(raw);
    if (secs == null || secs < 0) return null;
    return AccessControlMaxAgeHeader(Duration(seconds: secs));
  }

  /// The cached duration for preflight results.
  final Duration duration;

  @override
  String get name => HttpHeader.accessControlMaxAge.name;

  @override
  Iterable<String> encode() => [duration.inSeconds.toString()];

  @override
  String toString() => 'AccessControlMaxAgeHeader($duration)';
}

import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `User-Agent` request header field,
/// defined in [RFC 7231 Section 5.5.3](https://datatracker.ietf.org/doc/html/rfc7231#section-5.5.3).
///
/// Contains information about user agent originating the request.
///
/// ```dart
/// const ua = UserAgentHeader('hyper/0.12.2');
/// final decoded = UserAgentHeader.decode(['CERN-LineMode/2.15 libwww/2.17b3']);
/// ```
final class UserAgentHeader implements TypedHeader {
  /// Creates a `User-Agent` header with the given agent string.
  const UserAgentHeader(this.value);

  /// Decodes this header type from raw header values.
  static UserAgentHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (raw.isEmpty) return null;
    return UserAgentHeader(raw);
  }

  /// User agent details string.
  final String value;

  @override
  String get name => HttpHeader.userAgent.name;

  @override
  Iterable<String> encode() => [value];

  @override
  String toString() => 'UserAgentHeader($value)';
}

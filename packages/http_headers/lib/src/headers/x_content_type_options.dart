import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `X-Content-Type-Options` response header field,
/// defined in [Fetch Standard](https://fetch.spec.whatwg.org/#x-content-type-options-header).
///
/// Used by the server to indicate that the MIME types advertised in the
/// Content-Type headers should not be changed and be followed.
///
/// ```dart
/// const nosniff = XContentTypeOptionsHeader.nosniff();
/// final decoded = XContentTypeOptionsHeader.decode(['nosniff']);
/// ```
final class XContentTypeOptionsHeader implements TypedHeader {
  /// Creates an `X-Content-Type-Options` header with custom options.
  const XContentTypeOptionsHeader(this.options);

  /// Creates an `X-Content-Type-Options: nosniff` header.
  const XContentTypeOptionsHeader.nosniff() : options = 'nosniff';

  /// Decodes this header type from raw header values.
  static XContentTypeOptionsHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (raw.isEmpty) return null;
    if (raw.toLowerCase() == 'nosniff') {
      return const XContentTypeOptionsHeader.nosniff();
    }
    return XContentTypeOptionsHeader(raw);
  }

  /// The options string.
  final String options;

  @override
  String get name => HttpHeader.xContentTypeOptions.name;

  @override
  Iterable<String> encode() => [options];

  @override
  String toString() => 'XContentTypeOptionsHeader($options)';
}

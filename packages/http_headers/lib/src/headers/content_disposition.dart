import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Content-Disposition` response header field,
/// defined in [RFC 6266](https://datatracker.ietf.org/doc/html/rfc6266).
///
/// Conveys additional information about how to process the response payload.
///
/// ```dart
/// const cdInline = ContentDispositionHeader.inline();
/// final decoded =
///     ContentDispositionHeader.decode(['attachment; filename="file.txt"']);
/// ```
final class ContentDispositionHeader implements TypedHeader {
  /// Creates a `Content-Disposition` header with raw header value string.
  const ContentDispositionHeader(this.value);

  /// Creates a `Content-Disposition: inline` header.
  const ContentDispositionHeader.inline() : value = 'inline';

  /// Creates a `Content-Disposition: attachment` header.
  const ContentDispositionHeader.attachment() : value = 'attachment';

  /// Decodes this header type from raw header values.
  static ContentDispositionHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (raw.isEmpty) return null;
    return ContentDispositionHeader(raw);
  }

  /// The header value string.
  final String value;

  @override
  String get name => HttpHeader.contentDisposition.name;

  /// Disposition type prefix (e.g. `inline`, `attachment`, `form-data`).
  String get dispositionType {
    final idx = value.indexOf(';');
    if (idx == -1) return value.trim().toLowerCase();
    return value.substring(0, idx).trim().toLowerCase();
  }

  /// Returns `true` if disposition-type is `inline`.
  bool get isInline => dispositionType == 'inline';

  /// Returns `true` if disposition-type is `attachment`.
  bool get isAttachment => dispositionType == 'attachment';

  /// Returns `true` if disposition-type is `form-data`.
  bool get isFormData => dispositionType == 'form-data';

  @override
  Iterable<String> encode() => [value];

  @override
  String toString() => 'ContentDispositionHeader($value)';
}

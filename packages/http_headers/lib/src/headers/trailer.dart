import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Trailer` response header field,
/// defined in [RFC 9110 Section 6.6.2](https://datatracker.ietf.org/doc/html/rfc9110#section-6.6.2).
///
/// Allows the sender to include additional fields at the end of a chunked
/// message.
///
/// ```dart
/// final trailer = TrailerHeader(['Expires']);
/// final decoded = TrailerHeader.decode(['Expires', 'Date']);
/// ```
final class TrailerHeader implements TypedHeader {
  /// Creates a `Trailer` header with the given list of field names.
  const TrailerHeader(this.fieldNames);

  /// Decodes this header type from raw header values.
  static TrailerHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final fields = <String>[];
    for (final value in values) {
      final parts = value.split(',');
      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.isNotEmpty) {
          fields.add(trimmed);
        }
      }
    }
    if (fields.isEmpty) return null;
    return TrailerHeader(fields);
  }

  /// The list of header field names.
  final List<String> fieldNames;

  @override
  String get name => HttpHeader.trailer.name;

  @override
  Iterable<String> encode() => [fieldNames.join(', ')];

  @override
  String toString() => 'TrailerHeader(${fieldNames.join(', ')})';
}

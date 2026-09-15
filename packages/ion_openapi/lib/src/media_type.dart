import 'package:json_schema_builder/json_schema_builder.dart';

/// Represents a Media Type object, describing the data format and schema.
///
/// ```dart
/// final jsonMedia = ApiMediaType.json(.object({
///   'id': .integer(),
///   'name': .string(),
/// }));
/// ```
class ApiMediaType {
  const ApiMediaType(
    this.contentType,
    this.schema, {
    this.isStreaming = false,
  });

  const ApiMediaType.json(this.schema)
    : contentType = 'application/json',
      isStreaming = false;

  ApiMediaType.text()
    : contentType = 'text/plain',
      schema = .string(),
      isStreaming = false;

  const ApiMediaType.form(this.schema)
    : contentType = 'application/x-www-form-urlencoded',
      isStreaming = false;

  const ApiMediaType.multipart(this.schema)
    : contentType = 'multipart/form-data',
      isStreaming = false;

  ApiMediaType.binary([String? contentType])
    : contentType = contentType ?? 'application/octet-stream',
      schema = .string(format: 'binary'),
      isStreaming = false;

  const ApiMediaType.sse(this.schema)
    : contentType = 'text/event-stream',
      isStreaming = true;

  final String contentType;
  final Schema schema;
  final bool isStreaming;

  Map<String, Object?> toJson() {
    return {
      'schema': schema.value,
      if (isStreaming) 'itemSchema': schema.value,
    };
  }
}

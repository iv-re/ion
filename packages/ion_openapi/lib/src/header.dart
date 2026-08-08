import 'package:json_schema_builder/json_schema_builder.dart';

/// Represents an API header for an operation response or request.
///
/// ```dart
/// final header = ApiHeader(
///   description: 'The number of allowed requests in the current period',
///   schema: .integer(),
/// );
/// ```
class ApiHeader {
  const ApiHeader({
    this.description,
    this.required = false,
    this.deprecated = false,
    this.schema,
  });

  final String? description;
  final bool required;
  final bool deprecated;
  final Schema? schema;

  Map<String, Object?> toJson() => {
    'description': ?description,
    if (required) 'required': true,
    if (deprecated) 'deprecated': true,
    'schema': ?schema?.value,
  };
}

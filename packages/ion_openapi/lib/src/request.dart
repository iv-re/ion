import 'package:ion_openapi/src/media_type.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

enum ApiParameterLocation { query, header, path, cookie }

/// Describes a single operation parameter (path, query, header, or cookie).
///
/// ```dart
/// final param = ApiParameter.query(
///   'status',
///   description: 'Filter users by status',
///   schema: .string(),
/// );
/// ```
class ApiParameter {
  const ApiParameter({
    required this.name,
    required this.inLocation,
    this.description,
    this.required = false,
    this.deprecated = false,
    this.schema,
  });

  const ApiParameter.path(
    this.name, {
    this.description,
    this.schema,
  }) : inLocation = .path,
       required = true,
       deprecated = false;

  const ApiParameter.query(
    this.name, {
    this.description,
    this.required = false,
    this.schema,
  }) : inLocation = .query,
       deprecated = false;

  const ApiParameter.header(
    this.name, {
    this.description,
    this.required = false,
    this.schema,
  }) : inLocation = .header,
       deprecated = false;

  const ApiParameter.cookie(
    this.name, {
    this.description,
    this.required = false,
    this.schema,
  }) : inLocation = .cookie,
       deprecated = false;

  final String name;
  final ApiParameterLocation inLocation;
  final String? description;
  final bool required;
  final bool deprecated;
  final Schema? schema;

  Map<String, Object?> toJson() => {
    'name': name,
    'in': inLocation.name,
    'description': ?description,
    'required': required,
    if (deprecated) 'deprecated': true,
    'schema': ?schema?.value,
  };
}

/// Describes a single request body for an operation.
///
/// ```dart
/// final body = ApiRequestBody.json(
///   .object({
///     'name': .string(),
///     'email': .string(format: 'email'),
///   }),
///   description: 'The user to create.',
/// );
/// ```
class ApiRequestBody {
  const ApiRequestBody({
    required this.content,
    this.description,
    this.required = true,
  });

  ApiRequestBody.json(
    Schema schema, {
    this.description,
    this.required = true,
  }) : content = .json(schema);

  ApiRequestBody.form(
    Schema schema, {
    this.description,
    this.required = true,
  }) : content = .form(schema);

  ApiRequestBody.multipart(
    Schema schema, {
    this.description,
    this.required = true,
  }) : content = .multipart(schema);

  ApiRequestBody.binary({
    this.description,
    String? contentType,
    this.required = true,
  }) : content = .binary(contentType);

  final ApiMediaType content;
  final String? description;
  final bool required;

  Map<String, Object?> toJson() => {
    'description': ?description,
    'required': required,
    'content': {
      content.contentType: content.toJson(),
    },
  };
}

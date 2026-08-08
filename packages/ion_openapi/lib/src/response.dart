import 'package:ion_openapi/src/header.dart';
import 'package:ion_openapi/src/link.dart';
import 'package:ion_openapi/src/media_type.dart';

import 'package:json_schema_builder/json_schema_builder.dart';

/// Describes a single API response for an operation.
///
/// ```dart
/// final response = ApiResponse.json(
///   .object({'id': .integer()}),
///   description: 'Successfully created item.',
/// );
/// ```
class ApiResponse {
  const ApiResponse({
    required this.description,
    this.content,
    this.headers,
    this.links,
  });

  ApiResponse.json(
    Schema schema, {
    String? description,
    this.headers,
    this.links,
  }) : description = description ?? 'Success',
       content = .json(schema);

  ApiResponse.text({
    String? description,
    this.headers,
    this.links,
  }) : description = description ?? 'Success',
       content = .text();

  ApiResponse.sse(
    Schema schema, {
    String? description,
    this.headers,
    this.links,
  }) : description = description ?? 'Server-Sent Events Stream',
       content = .sse(schema);

  ApiResponse.binary({
    String? description,
    String? contentType,
    this.headers,
    this.links,
  }) : description = description ?? 'File download',
       content = .binary(contentType);

  const ApiResponse.empty({
    String? description,
    this.headers,
    this.links,
  }) : description = description ?? 'Success',
       content = null;

  final String description;
  final ApiMediaType? content;
  final Map<String, ApiHeader>? headers;
  final Map<String, ApiLink>? links;

  Map<String, Object?> toJson() => {
    'description': description,
    if (content case final content?)
      'content': {
        content.contentType: content.toJson(),
      },
    if (headers case final headers? when headers.isNotEmpty)
      'headers': {
        for (final entry in headers.entries) entry.key: entry.value.toJson(),
      },
    if (links case final links? when links.isNotEmpty)
      'links': {
        for (final entry in links.entries) entry.key: entry.value.toJson(),
      },
  };
}

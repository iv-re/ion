import 'package:ion_openapi/src/external_docs.dart';
import 'package:ion_openapi/src/request.dart';
import 'package:ion_openapi/src/response.dart';
import 'package:ion_openapi/src/security.dart';
import 'package:ion_openapi/src/server.dart';
import 'package:ion_web/ion_web.dart';

/// Describes a single API operation (e.g., a GET or POST request) on a path.
///
/// ```dart
/// final operation = ApiOperation(
///   summary: 'Get User',
///   description: 'Retrieves a user by ID.',
///   tags: ['users'],
///   parameters: [
///     .path('id', schema: .integer()),
///   ],
///   responses: {
///     .ok: .json(
///       .object({'name': .string()}),
///       description: 'The user object.',
///     ),
///   },
/// );
/// ```
class ApiOperation {
  const ApiOperation({
    this.summary,
    this.description,
    this.tags,
    this.operationId,
    this.deprecated = false,
    this.externalDocs,
    this.parameters,
    this.body,
    this.responses,
    this.security,
    this.servers,
  });

  final String? summary;
  final String? description;
  final List<String>? tags;
  final String? operationId;
  final bool deprecated;
  final ApiExternalDocs? externalDocs;

  final List<ApiParameter>? parameters;
  final ApiRequestBody? body;
  final Map<HttpStatusCode, ApiResponse>? responses;
  final List<ApiSecurityRequirement>? security;
  final List<ApiServer>? servers;

  ApiOperation copyWith({
    String? summary,
    String? description,
    List<String>? tags,
    String? operationId,
    bool? deprecated,
    ApiExternalDocs? externalDocs,
    List<ApiParameter>? parameters,
    ApiRequestBody? body,
    Map<HttpStatusCode, ApiResponse>? responses,
    List<ApiSecurityRequirement>? security,
    List<ApiServer>? servers,
  }) {
    return ApiOperation(
      summary: summary ?? this.summary,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      operationId: operationId ?? this.operationId,
      deprecated: deprecated ?? this.deprecated,
      externalDocs: externalDocs ?? this.externalDocs,
      parameters: parameters ?? this.parameters,
      body: body ?? this.body,
      responses: responses ?? this.responses,
      security: security ?? this.security,
      servers: servers ?? this.servers,
    );
  }

  Map<String, Object?> toJson() => {
    'summary': ?summary,
    'description': ?description,
    if (tags case final tags? when tags.isNotEmpty) 'tags': tags,
    'operationId': ?operationId,
    if (deprecated) 'deprecated': true,
    'externalDocs': ?externalDocs?.toJson(),
    if (parameters case final parameters? when parameters.isNotEmpty)
      'parameters': parameters.map((p) => p.toJson()).toList(),
    'requestBody': ?body?.toJson(),
    if (responses case final responses? when responses.isNotEmpty)
      'responses': {
        for (final entry in responses.entries)
          entry.key.value.toString(): entry.value.toJson(),
      }
    else
      'responses': {
        'default': {'description': 'No response documented.'},
      },
    if (security case final security? when security.isNotEmpty)
      'security': security.map((s) => s.toJson()).toList(),
    if (servers case final servers? when servers.isNotEmpty)
      'servers': servers.map((s) => s.toJson()).toList(),
  };
}

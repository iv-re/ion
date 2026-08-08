import 'package:ion_openapi/src/server.dart';

/// Represents a possible design-time link for a response.
///
/// ```dart
/// final link = ApiLink(
///   operationId: 'getUserAddress',
///   parameters: {'userId': r'$request.path.id'},
///   description: 'The user address associated with the returned user id.',
/// );
/// ```
class ApiLink {
  const ApiLink({
    this.operationRef,
    this.operationId,
    this.parameters,
    this.requestBody,
    this.description,
    this.server,
  });

  final String? operationRef;
  final String? operationId;
  final Map<String, Object?>? parameters;
  final Object? requestBody;
  final String? description;
  final ApiServer? server;

  Map<String, Object?> toJson() => {
    'operationRef': ?operationRef,
    'operationId': ?operationId,
    if (parameters case final parameters? when parameters.isNotEmpty)
      'parameters': parameters,
    'requestBody': ?requestBody,
    'description': ?description,
    'server': ?server?.toJson(),
  };
}

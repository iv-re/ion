/// Represents a Server Variable for server URL template substitution.
///
/// ```dart
/// final variable = ApiServerVariable(
///   defaultValue: '8443',
///   enumValues: ['8443', '443'],
///   description: 'Port number',
/// );
/// ```
class ApiServerVariable {
  const ApiServerVariable({
    required this.defaultValue,
    this.description,
    this.enumValues,
  });

  final String defaultValue;
  final String? description;
  final List<String>? enumValues;

  Map<String, Object?> toJson() => {
    'default': defaultValue,
    'description': ?description,
    if (enumValues case final enumValues? when enumValues.isNotEmpty)
      'enum': enumValues,
  };
}

/// Represents a Server object.
///
/// ```dart
/// final server = ApiServer(
///   url: 'https://{environment}.example.com/v1',
///   description: 'The main API server',
///   variables: {
///     'environment': ApiServerVariable(
///       defaultValue: 'api',
///       enumValues: ['api', 'api.dev', 'api.staging'],
///     ),
///   },
/// );
/// ```
class ApiServer {
  const ApiServer({
    required this.url,
    this.description,
    this.variables,
  });

  final String url;
  final String? description;
  final Map<String, ApiServerVariable>? variables;

  Map<String, Object?> toJson() => {
    'url': url,
    'description': ?description,
    if (variables case final variables? when variables.isNotEmpty)
      'variables': {
        for (final entry in variables.entries) entry.key: entry.value.toJson(),
      },
  };
}

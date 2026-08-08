/// Represents a security scheme (e.g., HTTP Basic, Bearer, API Key, OAuth2)
///
/// ```dart
/// final scheme = ApiSecurityScheme.httpBearer(
///   bearerFormat: 'JWT',
///   description: 'JWT Authorization header using the Bearer scheme.',
/// );
/// ```
class ApiSecurityScheme {
  const ApiSecurityScheme({
    required this.key,
    required this.type,
    this.description,
    this.name,
    this.inLocation,
    this.scheme,
    this.bearerFormat,
    this.flows,
    this.openIdConnectUrl,
  });

  factory ApiSecurityScheme.httpBearer({
    String key = 'bearerAuth',
    String bearerFormat = 'JWT',
    String? description,
  }) {
    return ApiSecurityScheme(
      key: key,
      type: 'http',
      scheme: 'bearer',
      bearerFormat: bearerFormat,
      description: description,
    );
  }

  factory ApiSecurityScheme.httpBasic({
    String key = 'basicAuth',
    String? description,
  }) {
    return ApiSecurityScheme(
      key: key,
      type: 'http',
      scheme: 'basic',
      description: description,
    );
  }

  factory ApiSecurityScheme.apiKey({
    required String name,
    required String inLocation,
    String key = 'apiKey',
    String? description,
  }) {
    return ApiSecurityScheme(
      key: key,
      type: 'apiKey',
      name: name,
      inLocation: inLocation,
      description: description,
    );
  }

  final String key;
  final String type;
  final String? description;
  final String? name;
  final String? inLocation;
  final String? scheme;
  final String? bearerFormat;
  final Map<String, Object?>? flows;
  final String? openIdConnectUrl;

  Map<String, Object?> toJson() => {
    'type': type,
    'description': ?description,
    'name': ?name,
    'in': ?inLocation,
    'scheme': ?scheme,
    'bearerFormat': ?bearerFormat,
    if (flows case final flows? when flows.isNotEmpty) 'flows': flows,
    'openIdConnectUrl': ?openIdConnectUrl,
  };
}

/// Holds reusable security schemes, schemas, and other components.
///
/// ```dart
/// final components = ApiComponents(
///   securitySchemes: [
///     .httpBearer(),
///   ],
/// );
/// ```
class ApiComponents {
  const ApiComponents({
    this.securitySchemes,
  });

  final List<ApiSecurityScheme>? securitySchemes;

  Map<String, Object?> toJson() => {
    if (securitySchemes case final schemes? when schemes.isNotEmpty)
      'securitySchemes': {
        for (final scheme in schemes) scheme.key: scheme.toJson(),
      },
  };
}

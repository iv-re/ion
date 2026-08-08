import 'package:ion_extra/ion_extra.dart';
import 'package:ion_openapi/src/components.dart';
import 'package:ion_openapi/src/external_docs.dart';
import 'package:ion_openapi/src/operation.dart';
import 'package:ion_openapi/src/security.dart';
import 'package:ion_openapi/src/server.dart';
import 'package:ion_openapi/src/tag.dart';
import 'package:ion_openapi/src/webhook.dart';
import 'package:ion_router/ion_router.dart';

/// Provides metadata about the API.
///
/// ```dart
/// final info = OpenApiInfo(
///   title: 'My Awesome API',
///   version: '1.0.0',
///   description: 'API for my awesome app',
/// );
/// ```
class OpenApiInfo {
  const OpenApiInfo({
    required this.title,
    required this.version,
    this.description,
  });

  final String title;
  final String version;
  final String? description;

  Map<String, Object?> toJson() => {
    'title': title,
    'version': version,
    'description': ?description,
  };
}

/// Represents the root specification object.
///
/// ```dart
/// final openApi = OpenApi.fromRouter(
///   router,
///   info: OpenApiInfo(
///     title: 'My Awesome API',
///     version: '1.0.0',
///   ),
///   servers: [
///     ApiServer(url: 'https://api.example.com/v1'),
///   ],
///   tags: [
///     ApiTag(name: 'users', description: 'User management'),
///   ],
///   components: ApiComponents(
///     securitySchemes: [.httpBearer()],
///   ),
/// );
/// ```
class OpenApi implements ToJson {
  OpenApi.fromRouter(
    Routes router, {
    required this.info,
    this.servers,
    this.security,
    this.tags,
    this.externalDocs,
    this.components,
    this.webhooks,
  }) {
    _buildPaths(router);
  }

  final OpenApiInfo info;
  final List<ApiServer>? servers;
  final List<ApiSecurityRequirement>? security;
  final List<ApiTag>? tags;
  final ApiExternalDocs? externalDocs;
  final ApiComponents? components;
  final Map<String, ApiWebhook>? webhooks;

  final Map<String, Map<String, ApiOperation>> _paths = {};
  final Map<String, Object?> _extractedSchemas = {};

  static final _pathParamRegExp = RegExp(r'\{([^}]+)\}');

  void _buildPaths(Routes router) {
    router.walk((method, fullRoute, middlewares, meta) {
      final operation = meta.whereType<ApiOperation>().firstOrNull;
      if (operation == null) return;

      // Automatically extract path parameters from route (e.g. /users/{id})
      final parameters = operation.parameters?.toList() ?? [];
      var hasNewParams = false;

      for (final match in _pathParamRegExp.allMatches(fullRoute)) {
        final paramName = match.group(1);
        if (paramName == null) continue;

        if (!parameters.any(
          (p) => p.inLocation == .path && p.name == paramName,
        )) {
          parameters.add(.path(paramName, schema: .string()));
          hasNewParams = true;
        }
      }

      _paths.putIfAbsent(fullRoute, () => {})[method.value.toLowerCase()] =
          hasNewParams ? operation.copyWith(parameters: parameters) : operation;
    });
  }

  @override
  Map<String, Object?> toJson() {
    final extractedWebhooks = webhooks?.map(
      (key, value) => MapEntry(key, _extractSchemas(value.toJson())),
    );

    final pathsJson = _paths.map(
      (path, methods) => MapEntry(
        path,
        methods.map((m, op) => MapEntry(m, _extractSchemas(op.toJson()))),
      ),
    );

    final componentsJson = components?.toJson() ?? <String, Object?>{};
    if (_extractedSchemas.isNotEmpty) {
      componentsJson['schemas'] = {
        ...?componentsJson['schemas'] as Map<String, Object?>?,
        ..._extractedSchemas,
      };
    }

    return {
      'openapi': '3.2.0',
      'info': info.toJson(),
      if (servers case final servers? when servers.isNotEmpty)
        'servers': servers.map((s) => s.toJson()).toList(),
      if (security case final security? when security.isNotEmpty)
        'security': security.map((s) => s.toJson()).toList(),
      if (tags case final tags? when tags.isNotEmpty)
        'tags': tags.map((t) => t.toJson()).toList(),
      'externalDocs': ?externalDocs?.toJson(),
      'paths': pathsJson,
      if (extractedWebhooks != null && extractedWebhooks.isNotEmpty)
        'webhooks': extractedWebhooks,
      if (componentsJson.isNotEmpty) 'components': componentsJson,
    };
  }

  Object? _extractSchemas(Object? node) {
    if (node is List) {
      return node.map(_extractSchemas).toList();
    } else if (node is Map<String, Object?>) {
      final title = node['title'];

      if (title is String && title.isNotEmpty && !node.containsKey(r'$ref')) {
        _extractedSchemas[title] = node.map(
          (key, value) => MapEntry(key, _extractSchemas(value)),
        );
        return {r'$ref': '#/components/schemas/$title'};
      }

      return node.map((key, value) => MapEntry(key, _extractSchemas(value)));
    }
    return node;
  }
}

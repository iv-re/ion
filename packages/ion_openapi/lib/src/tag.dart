import 'package:ion_openapi/src/external_docs.dart';

/// Allows adding metadata to a single tag that is used by operations.
///
/// ```dart
/// final tag = ApiTag(
///   name: 'users',
///   description: 'Operations related to user management',
/// );
/// ```
class ApiTag {
  const ApiTag({
    required this.name,
    this.summary,
    this.description,
    this.externalDocs,
    this.parent,
    this.kind,
  });

  final String name;
  final String? summary;
  final String? description;
  final ApiExternalDocs? externalDocs;
  final String? parent;
  final String? kind;

  Map<String, Object?> toJson() => {
    'name': name,
    'summary': ?summary,
    'description': ?description,
    'externalDocs': ?externalDocs?.toJson(),
    'parent': ?parent,
    'kind': ?kind,
  };
}

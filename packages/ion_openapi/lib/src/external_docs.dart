/// Allows referencing an external resource for extended documentation.
///
/// ```dart
/// final docs = ApiExternalDocs(
///   url: 'https://example.com/docs',
///   description: 'Find more info here',
/// );
/// ```
class ApiExternalDocs {
  const ApiExternalDocs({
    required this.url,
    this.description,
  });

  final String url;
  final String? description;

  Map<String, Object?> toJson() => {
    'url': url,
    'description': ?description,
  };
}

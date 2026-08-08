/// Lists the required security schemes to execute an operation.
///
/// ```dart
/// final operation = ApiOperation(
///   summary: 'Secure endpoint',
///   security: [
///     // Any of these (Logical OR):
///     .bearer(),
///     .custom('myAuth', ['admin']),
///     // Or combined requirements (Logical AND):
///     ApiSecurityRequirement.bearer() & ApiSecurityRequirement.apiKey(),
///   ],
/// );
/// ```
class ApiSecurityRequirement {
  const ApiSecurityRequirement(this.schemes);

  ApiSecurityRequirement.bearer({String name = 'bearerAuth'})
    : schemes = {name: const []};

  ApiSecurityRequirement.oauth2(
    List<String> scopes, {
    String name = 'oauth2',
  }) : schemes = {name: scopes};

  ApiSecurityRequirement.apiKey({String name = 'apiKey'})
    : schemes = {name: const []};

  ApiSecurityRequirement.basic({String name = 'basicAuth'})
    : schemes = {name: const []};

  ApiSecurityRequirement.custom(
    String name, [
    List<String> scopes = const [],
  ]) : schemes = {name: scopes};

  final Map<String, List<String>> schemes;

  Map<String, List<String>> toJson() => schemes;

  /// Combines this requirement with another using logical AND.
  ApiSecurityRequirement operator &(ApiSecurityRequirement other) {
    return ApiSecurityRequirement({...schemes, ...other.schemes});
  }
}

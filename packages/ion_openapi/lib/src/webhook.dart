import 'package:ion_openapi/src/operation.dart';

/// Describes a webhook that may be received as part of the API.
///
/// ```dart
/// final webhook = ApiWebhook(
///   post: ApiOperation(
///     summary: 'New user created',
///     body: .json(.object({'id': .integer()})),
///   ),
/// );
/// ```
class ApiWebhook {
  const ApiWebhook({
    this.post,
    this.get,
    this.put,
    this.patch,
    this.delete,
  });

  final ApiOperation? post;
  final ApiOperation? get;
  final ApiOperation? put;
  final ApiOperation? patch;
  final ApiOperation? delete;

  Map<String, Object?> toJson() => {
    'post': ?post?.toJson(),
    'get': ?get?.toJson(),
    'put': ?put?.toJson(),
    'patch': ?patch?.toJson(),
    'delete': ?delete?.toJson(),
  };
}

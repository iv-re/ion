import 'package:equatable/equatable.dart';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Access-Control-Allow-Credentials` response header,
/// part of [CORS](https://fetch.spec.whatwg.org/#http-access-control-allow-credentials).
///
/// Indicates whether the response to the request can be exposed when the
/// credentials flag is true.
///
/// ```dart
/// const allowCreds = AccessControlAllowCredentialsHeader();
/// final decoded = AccessControlAllowCredentialsHeader.decode(['true']);
/// ```
final class AccessControlAllowCredentialsHeader extends Equatable
    implements TypedHeader {
  /// Creates an `Access-Control-Allow-Credentials: true` header.
  const AccessControlAllowCredentialsHeader();

  /// Decodes this header type from raw header values.
  static AccessControlAllowCredentialsHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (raw == 'true') {
      return const AccessControlAllowCredentialsHeader();
    }
    return null;
  }

  @override
  String get name => HttpHeader.accessControlAllowCredentials.name;

  @override
  Iterable<String> encode() => const ['true'];

  @override
  List<Object?> get props => [];
}

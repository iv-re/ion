import 'dart:async';
import 'dart:typed_data';

import 'package:ion_router/src/middleware.dart';
import 'package:ion_web/ion_web.dart';

/// Exception thrown when the request body exceeds the configured size limit.
final class BodyLimitExceededException implements Exception {
  const BodyLimitExceededException(this.limit);

  /// The configured limit in bytes.
  final int limit;

  @override
  String toString() => 'BodyLimitExceededException: body exceeds $limit bytes';
}

/// Creates a [Middleware] that rejects requests whose body exceeds [maxBytes].
///
/// Returns `413 Content Too Large` if:
/// - The `Content-Length` header value exceeds [maxBytes] (fast-path, body is
///   never read), or
/// - The actual body stream exceeds [maxBytes] during reading.
///
/// If [onExceeded] is provided, it is called to produce the response instead
/// of the default `413 Content Too Large`.
///
/// ```dart
/// app.use(Middlewares.bodyLimit(1 * 1024 * 1024)); // 1 MB
///
/// // Custom response (using RawJson from ion_extra)
/// app.use(Middlewares.bodyLimit(
///   512 * 1024,
///   onExceeded: (req) => RawJson(
///     {'error': 'body too large'},
///     status: .contentTooLarge,
///   ),
/// ));
/// ```
Middleware bodyLimitMiddleware(
  int maxBytes, {
  Response Function(Request req)? onExceeded,
}) {
  return (Handler next) {
    return (Request req) async {
      // Fast-path: Content-Length is known and already exceeds the limit.
      final contentLength = req.headers.contentLength?.bytes;
      if (contentLength != null && contentLength > maxBytes) {
        return onExceeded?.call(req) ?? const Response.status(.contentTooLarge);
      }

      // Wrap the body stream so that reading beyond [maxBytes] throws
      // [BodyLimitExceededException].
      final limited = _LimitedBodyStream(req, maxBytes);
      final limitedReq = req.copyWith(body: limited);

      try {
        return await next(limitedReq);
      } on BodyLimitExceededException {
        return onExceeded?.call(req) ?? const Response.status(.contentTooLarge);
      }
    };
  };
}

/// A [Stream<Uint8List>] that counts bytes as they pass through and throws
/// [BodyLimitExceededException] as soon as the total exceeds [_maxBytes].
class _LimitedBodyStream extends Stream<Uint8List> {
  _LimitedBodyStream(this._source, this._maxBytes);

  final Stream<Uint8List> _source;
  final int _maxBytes;

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    var bytesRead = 0;

    late final StreamSubscription<Uint8List> sub;

    return sub = _source.listen(
      (chunk) {
        bytesRead += chunk.length;
        if (bytesRead > _maxBytes) {
          sub.cancel();
          // ignore: avoid_dynamic_calls
          onError?.call(
            BodyLimitExceededException(_maxBytes),
            StackTrace.empty,
          );
          return;
        }
        onData?.call(chunk);
      },
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError ?? false,
    );
  }
}

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
      final limitedReq = req.copyWith(body: req.transform(_limit(maxBytes)));

      try {
        return await next(limitedReq);
      } on BodyLimitExceededException {
        return onExceeded?.call(req) ?? const Response.status(.contentTooLarge);
      }
    };
  };
}

/// Passes chunks through until more than [maxBytes] have been seen, then
/// emits [BodyLimitExceededException] and closes, which cancels the source.
///
/// A transformer rather than a custom [Stream.listen]: consumers such as
/// [Stream.cast] and [Stream.drain] replace the handlers of the subscription
/// they get back, so the limit has to live inside the stream itself.
StreamTransformer<Uint8List, Uint8List> _limit(int maxBytes) {
  var bytesRead = 0;
  var exceeded = false;
  return StreamTransformer.fromHandlers(
    handleData: (chunk, sink) {
      if (exceeded) return;
      bytesRead += chunk.length;
      if (bytesRead > maxBytes) {
        exceeded = true;
        sink
          ..addError(BodyLimitExceededException(maxBytes))
          ..close();
        return;
      }
      sink.add(chunk);
    },
  );
}

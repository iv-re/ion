import 'dart:async';

import 'package:ctx/ctx.dart';
import 'package:ion_router/src/middleware.dart';
import 'package:ion_web/ion_web.dart';

/// Creates a [Middleware] that cancels the request [Context] and returns a
/// `504 Gateway Timeout` response if the inner [Handler] does not complete
/// within [duration].
///
/// If [onTimeout] is provided, it will be invoked to produce the timeout
/// [Response]; otherwise, a standard `504 Gateway Timeout` response is
/// returned.
///
/// ```dart
/// app.use(Middlewares.timeout(const Duration(seconds: 15)));
/// ```
Middleware timeoutMiddleware(
  Duration duration, {
  Response Function(Request req)? onTimeout,
}) {
  return (Handler next) {
    return (Request req) async {
      final (timeoutCtx, cancel) = req.ctx.withTimeout(duration);
      final updatedReq = req.copyWith(ctx: timeoutCtx);

      try {
        final resOrFuture = next(updatedReq);
        if (resOrFuture is Response) {
          return resOrFuture;
        }
        return await resOrFuture.timeout(duration);
      } on TimeoutException {
        return onTimeout?.call(updatedReq) ?? const .status(.gatewayTimeout);
      } on ContextTimeoutException {
        return onTimeout?.call(updatedReq) ?? const .status(.gatewayTimeout);
      } finally {
        cancel();
      }
    };
  };
}

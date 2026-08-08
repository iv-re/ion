import 'dart:async';

import 'package:ion_router/src/middleware.dart';
import 'package:ion_web/ion_web.dart';
import 'package:sl/sl.dart';

/// Type for custom error handler
typedef ErrorHandlerFn =
    FutureOr<Response> Function(
      Request req,
      Object error,
      StackTrace stackTrace,
    );

/// Creates a [Middleware] for global exception handling.
///
/// If [onError] is provided, all logic is delegated to it.
/// Otherwise, returns a standard 500 Internal Server Error response.
Middleware errorHandlerMiddleware({
  ErrorHandlerFn? onError,
  Logger? logger,
}) {
  return (Handler next) {
    return (Request req) async {
      try {
        return await next(req);
      } catch (error, stackTrace) {
        Response response;

        // Delegate to custom handler if provided
        if (onError != null) {
          response = await onError(req, error, stackTrace);
        } else {
          response = const .status(.internalServerError);
        }

        // Log the error if logger is provided
        if (logger != null && response.status >= .internalServerError) {
          logger.error(
            'unhandled exception in request',
            attrs: [
              .error(error),
              .stackTrace(stackTrace),
            ],
          );
        }

        return response;
      }
    };
  };
}

import 'package:ion_router/src/middleware.dart';
import 'package:ion_web/ion_web.dart';
import 'package:sl/sl.dart';

/// Creates a [Middleware] for HTTP request logging using structured [Logger].
Middleware loggerMiddleware({required Logger logger}) {
  return (Handler next) {
    return (Request req) async {
      final stopwatch = Stopwatch()..start();
      final response = await next(req);
      stopwatch.stop();

      final uri = req.uri;
      final path = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;

      logger.log(
        switch (response.status) {
          >= .internalServerError => .error,
          >= .badRequest => .warn,
          _ => .info,
        },
        'request processed',
        ctx: req.ctx,
        attrs: [
          .group('http', [
            .string('method', req.method.value),
            .string('path', path),
            .int('status', response.status.value),
            .int('duration_ms', stopwatch.elapsedMilliseconds),
            if (response.contentLength case final bytes?) .int('bytes', bytes),
          ]),
        ],
      );

      return response;
    };
  };
}

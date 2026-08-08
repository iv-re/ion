import 'package:ctx/ctx.dart';
import 'package:ion_router/src/middlewares/basic_auth.dart';
import 'package:ion_router/src/middlewares/body_limit.dart';
import 'package:ion_router/src/middlewares/client_ip.dart';
import 'package:ion_router/src/middlewares/cors.dart';
import 'package:ion_router/src/middlewares/error_handler.dart';
import 'package:ion_router/src/middlewares/logger.dart';
import 'package:ion_router/src/middlewares/request_id.dart';
import 'package:ion_router/src/middlewares/timeout.dart';
import 'package:ion_web/ion_web.dart';
import 'package:sl/sl.dart';

export 'package:ion_router/src/middlewares/client_ip.dart'
    show ClientIpContext, ClientIpSource;

export 'package:ion_router/src/middlewares/cors.dart' show CorsOptions;

export 'package:ion_router/src/middlewares/error_handler.dart'
    show ErrorHandlerFn;

export 'package:ion_router/src/middlewares/request_id.dart'
    show RequestIdContext, RequestIdHeader;

/// A middleware function that wraps an inner [Handler] and returns a new
/// [Handler].
typedef Middleware = Handler Function(Handler next);

/// Extension methods for [Middleware] composition.
extension MiddlewareComposition on Middleware {
  /// Chains this middleware with [other], executing `this` first
  /// and then [other].
  Middleware chain(Middleware other) {
    return (Handler next) => this(other(next));
  }

  /// Alias for [chain] using the `&` operator.
  Middleware operator &(Middleware other) => chain(other);
}

/// Entry point for standard `ion_router` middlewares.
abstract final class Middlewares {
  const Middlewares._();

  /// Middleware for CORS (Cross-Origin Resource Sharing).
  ///
  /// ```dart
  /// // Default configuration (wildcard * origins)
  /// Middlewares.cors();
  ///
  /// // Custom CORS options
  /// Middlewares.cors(
  ///   CorsOptions(
  ///     allowedOrigins: ['https://example.com'],
  ///     allowedMethods: [.get, .post],
  ///     allowedHeaders: [.contentType, .authorization],
  ///     allowCredentials: true,
  ///     maxAge: const Duration(hours: 1),
  ///   ),
  /// );
  ///
  /// // Permissive configuration allowing all origins, methods, and headers
  /// Middlewares.cors(CorsOptions.allowAll());
  /// ```
  static Middleware cors([CorsOptions? options]) {
    return corsMiddleware(options);
  }

  /// Middleware that cancels request [Context] and returns
  /// `504 Gateway Timeout` if inner [Handler] does not complete in [duration].
  ///
  /// ```dart
  /// Middlewares.timeout(const Duration(seconds: 15));
  /// ```
  static Middleware timeout(
    Duration duration, {
    Response Function(Request req)? onTimeout,
  }) {
    return timeoutMiddleware(duration, onTimeout: onTimeout);
  }

  /// Middleware that extracts and stores the client IP in request [Context].
  ///
  /// ```dart
  /// // Single trusted proxy header (default: X-Real-IP)
  /// Middlewares.clientIp(
  ///   source: .header(headerName: 'CF-Connecting-IP'),
  /// );
  ///
  /// // X-Forwarded-For with trusted CIDR subnets
  /// Middlewares.clientIp(
  ///   source: .xff(trustedPrefixes: ['10.0.0.0/8', '2606:4700::/32']),
  /// );
  ///
  /// // X-Forwarded-For with exact count of trusted proxy hops
  /// Middlewares.clientIp(source: .xffTrustedProxies(2));
  ///
  /// // Direct TCP connection without reverse proxy
  /// Middlewares.clientIp(source: .remoteAddr());
  /// ```
  static Middleware clientIp({
    ClientIpSource source = const .header(),
  }) {
    return clientIpMiddleware(source: source);
  }

  /// Middleware that injects a request ID into request context and
  /// sets the `X-Request-Id` (or custom) header on the returned response.
  static Middleware requestId({
    String headerName = 'X-Request-Id',
    String Function()? idGenerator,
  }) {
    return requestIdMiddleware(
      headerName: headerName,
      idGenerator: idGenerator,
    );
  }

  /// Middleware for HTTP Basic Authentication.
  ///
  /// Requires either [credentials] map (`username: password`) or a custom
  /// [authenticator] function `(username, password)`.
  static Middleware basicAuth({
    String realm = 'Restricted',
    Map<String, String>? credentials,
    bool Function(String username, String password)? authenticator,
  }) {
    return basicAuthMiddleware(
      realm: realm,
      credentials: credentials,
      authenticator: authenticator,
    );
  }

  /// Middleware for HTTP request logging using structured [Logger].
  static Middleware logger({required Logger logger}) {
    return loggerMiddleware(logger: logger);
  }

  /// Middleware for global exception handling.
  ///
  /// Catch all unhandled exceptions and return a standard 500 response,
  /// or delegate to a custom [onError] handler.
  static Middleware errorHandler({
    ErrorHandlerFn? onError,
    Logger? logger,
  }) {
    return errorHandlerMiddleware(
      onError: onError,
      logger: logger,
    );
  }

  /// Middleware that rejects requests whose body exceeds [maxBytes].
  ///
  /// Returns `413 Content Too Large` if:
  /// - The `Content-Length` header value exceeds [maxBytes] (fast-path,
  ///   body is never read), or
  /// - The actual body stream exceeds [maxBytes] during reading.
  ///
  /// If [onExceeded] is provided, it is called to produce the response
  /// instead of the default `413 Content Too Large`.
  ///
  /// ```dart
  /// app.use(Middlewares.bodyLimit(1 * 1024 * 1024)); // 1 MB
  /// ```
  static Middleware bodyLimit(
    int maxBytes, {
    Response Function(Request req)? onExceeded,
  }) {
    return bodyLimitMiddleware(maxBytes, onExceeded: onExceeded);
  }
}

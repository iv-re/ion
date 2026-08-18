import 'package:ion_router/src/middleware.dart';
import 'package:ion_web/ion_web.dart';

/// Configuration options for [corsMiddleware].
final class CorsOptions {
  CorsOptions({
    this.allowedOrigins = const ['*'],
    this.allowOriginFunc,
    this.allowedMethods = const [
      .get,
      .post,
      .put,
      .delete,
      .options,
      .patch,
      .head,
    ],
    this.allowedHeaders = const [.accept, .authorization, .contentType],
    this.exposedHeaders = const [],
    this.allowCredentials = false,
    this.maxAge,
    this.optionsPassthrough = false,
  }) : _prebuiltAllowedMethodsHeader = AccessControlAllowMethodsHeader(
         allowedMethods.map((m) => m.value).toList(),
       ),
       _prebuiltAllowedHeadersHeader = AccessControlAllowHeadersHeader(
         allowedHeaders.map((h) => h.name).toList(),
       ),
       _prebuiltExposedHeadersHeader = exposedHeaders.isEmpty
           ? null
           : AccessControlExposeHeadersHeader(
               exposedHeaders.map((h) => h.name).toList(),
             ),
       _prebuiltMaxAgeHeader = maxAge == null
           ? null
           : AccessControlMaxAgeHeader(maxAge) {
    if (allowOriginFunc == null) {
      for (final origin in allowedOrigins) {
        if (origin == '*') {
          _allowedOriginsAll = true;
        } else if (origin.contains('*')) {
          _allowedWOrigins.add(_WildcardOrigin(origin));
        } else {
          _allowedOriginsNormalized.add(origin.toLowerCase());
        }
      }
    }

    for (final header in allowedHeaders) {
      if (header.name == '*') {
        _allowedHeadersAll = true;
      } else {
        _allowedHeadersNormalized.add(header.name.toLowerCase());
      }
    }
  }

  /// Permissive configuration allowing all origins with standard HTTP methods
  /// and headers.
  CorsOptions.allowAll()
    : this(
        allowedOrigins: const ['*'],
        allowedMethods: const [
          .get,
          .post,
          .put,
          .patch,
          .delete,
          .head,
          .options,
        ],
        allowedHeaders: const [HttpHeader('*')],
        allowCredentials: false,
      );

  /// List of origins allowed for cross-domain requests.
  ///
  /// Can contain exact origins (`"https://example.com"`), `"*"` (allow all), or
  /// wildcards (`"https://*.example.com"`).
  final List<String> allowedOrigins;

  /// Custom origin validation function.
  ///
  /// Takes the request and the `Origin` header string as arguments.
  /// If specified, [allowedOrigins] is ignored.
  final bool Function(Request request, String origin)? allowOriginFunc;

  /// List of HTTP methods allowed for cross-domain requests.
  final List<HttpMethod> allowedMethods;

  /// List of HTTP headers allowed in cross-domain requests.
  ///
  /// Can contain `HttpHeader('*')` to allow any requested header.
  final List<HttpHeader> allowedHeaders;

  /// List of HTTP headers safe to expose to client-side scripts.
  final List<HttpHeader> exposedHeaders;

  /// Indicates whether the request can include credentials (e.g. cookies,
  /// HTTP authorization).
  final bool allowCredentials;

  /// Indicates how long (maximum duration) preflight request results can be
  /// cached by browsers.
  final Duration? maxAge;

  /// Instructs preflight to let subsequent handlers process `OPTIONS` requests.
  final bool optionsPassthrough;

  // Pre-built header instances computed once during options setup
  final AccessControlAllowMethodsHeader _prebuiltAllowedMethodsHeader;
  final AccessControlAllowHeadersHeader _prebuiltAllowedHeadersHeader;
  final AccessControlExposeHeadersHeader? _prebuiltExposedHeadersHeader;
  final AccessControlMaxAgeHeader? _prebuiltMaxAgeHeader;

  bool _allowedOriginsAll = false;
  bool _allowedHeadersAll = false;
  final List<String> _allowedOriginsNormalized = [];
  final List<_WildcardOrigin> _allowedWOrigins = [];
  final Set<String> _allowedHeadersNormalized = {};

  bool _isOriginAllowed(Request request, String origin) {
    if (allowOriginFunc != null) {
      return allowOriginFunc!(request, origin);
    }
    if (_allowedOriginsAll) return true;

    final lowerOrigin = origin.toLowerCase();
    if (_allowedOriginsNormalized.contains(lowerOrigin)) return true;

    for (final wildcard in _allowedWOrigins) {
      if (wildcard.matches(lowerOrigin)) return true;
    }
    return false;
  }

  bool _isMethodAllowed(HttpMethod method) {
    return allowedMethods.contains(method);
  }

  bool _isHeaderAllowed(String headerName) {
    if (_allowedHeadersAll) return true;
    final lower = headerName.toLowerCase();
    if (lower == 'origin') return true;
    return _allowedHeadersNormalized.contains(lower);
  }
}

final class _WildcardOrigin {
  _WildcardOrigin(String pattern)
    : _prefix = pattern.substring(0, pattern.indexOf('*')).toLowerCase(),
      _suffix = pattern.substring(pattern.indexOf('*') + 1).toLowerCase();

  final String _prefix;
  final String _suffix;

  bool matches(String lowerOrigin) {
    return lowerOrigin.length >= _prefix.length + _suffix.length &&
        lowerOrigin.startsWith(_prefix) &&
        lowerOrigin.endsWith(_suffix);
  }
}

const HttpHeader _originHeader = HttpHeader.origin;
const _prebuiltVaryPreflight = VaryHeader([
  'Origin',
  'Access-Control-Request-Method',
  'Access-Control-Request-Headers',
]);
const _prebuiltVaryActual = VaryHeader(['Origin']);
const _prebuiltAllowOriginAny = AccessControlAllowOriginHeader.any();
const _prebuiltAllowCredentials = AccessControlAllowCredentialsHeader();

const _defaultActualResponseHeaders = <TypedHeader>[
  _prebuiltVaryActual,
  _prebuiltAllowOriginAny,
];

/// Creates a [Middleware] that handles CORS (Cross-Origin Resource Sharing).
///
/// ```dart
/// Middlewares.cors(
///   CorsOptions(
///     allowedOrigins: ['https://example.com'],
///     allowedMethods: [.get, .post],
///     allowedHeaders: [.contentType, .authorization],
///     allowCredentials: true,
///     maxAge: const Duration(hours: 1),
///   ),
/// );
/// ```
Middleware corsMiddleware([CorsOptions? options]) {
  final opts = options ?? CorsOptions();

  return (Handler next) {
    return (Request req) async {
      final originValues = req.headers.raw(_originHeader);
      if (originValues.isEmpty) {
        return next(req);
      }

      final origin = originValues.first.trim();
      if (origin.isEmpty) {
        return next(req);
      }

      final isAllowed = opts._isOriginAllowed(req, origin);

      // Preflight request handling (OPTIONS + Access-Control-Request-Method)
      final reqMethodHeader = req.headers.accessControlRequestMethod;
      if (req.method == .options && reqMethodHeader != null) {
        if (!isAllowed) {
          return const .status(.noContent);
        }

        final requestedMethodStr = reqMethodHeader.method.trim().toUpperCase();
        final requestedMethod = HttpMethod(requestedMethodStr);

        if (!opts._isMethodAllowed(requestedMethod)) {
          return const .status(.noContent);
        }

        final reqHeadersHeader = req.headers.accessControlRequestHeaders;
        if (reqHeadersHeader != null && reqHeadersHeader.headers.isNotEmpty) {
          for (final h in reqHeadersHeader.headers) {
            final trimmed = h.trim();
            if (trimmed.isNotEmpty && !opts._isHeaderAllowed(trimmed)) {
              return const .status(.noContent);
            }
          }
        }

        final responseHeaders = <TypedHeader>[_prebuiltVaryPreflight];

        if (opts._allowedOriginsAll && !opts.allowCredentials) {
          responseHeaders.add(_prebuiltAllowOriginAny);
        } else {
          responseHeaders.add(AccessControlAllowOriginHeader.origin(origin));
        }

        responseHeaders.add(opts._prebuiltAllowedMethodsHeader);

        if (reqHeadersHeader != null && reqHeadersHeader.headers.isNotEmpty) {
          if (opts._allowedHeadersAll) {
            responseHeaders.add(
              AccessControlAllowHeadersHeader(reqHeadersHeader.headers),
            );
          } else {
            responseHeaders.add(opts._prebuiltAllowedHeadersHeader);
          }
        } else if (opts.allowedHeaders.isNotEmpty) {
          responseHeaders.add(opts._prebuiltAllowedHeadersHeader);
        }

        if (opts.allowCredentials) {
          responseHeaders.add(_prebuiltAllowCredentials);
        }

        if (opts._prebuiltMaxAgeHeader case final maxAgeHeader?) {
          responseHeaders.add(maxAgeHeader);
        }

        if (opts.optionsPassthrough) {
          final res = await next(req);
          return res.withHeaders(responseHeaders);
        }

        return .status(.noContent, headers: responseHeaders);
      }

      // Actual request handling
      final res = await next(req);
      if (!isAllowed) {
        return res;
      }

      // Hot-path optimization for default configuration (* origins, no
      // credentials, no exposed headers)
      if (opts._allowedOriginsAll &&
          !opts.allowCredentials &&
          opts.exposedHeaders.isEmpty) {
        return res.withHeaders(_defaultActualResponseHeaders);
      }

      final responseHeaders = <TypedHeader>[_prebuiltVaryActual];

      if (opts._allowedOriginsAll && !opts.allowCredentials) {
        responseHeaders.add(_prebuiltAllowOriginAny);
      } else {
        responseHeaders.add(AccessControlAllowOriginHeader.origin(origin));
      }

      if (opts.allowCredentials) {
        responseHeaders.add(_prebuiltAllowCredentials);
      }

      if (opts._prebuiltExposedHeadersHeader case final exposedHeadersHeader?) {
        responseHeaders.add(exposedHeadersHeader);
      }

      return res.withHeaders(responseHeaders);
    };
  };
}

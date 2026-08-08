import 'package:ion_router/src/middleware.dart';
import 'package:ion_web/ion_web.dart';

/// Describes a single registered route.
class Route {
  /// Creates a route descriptor.
  const Route({
    required this.pattern,
    required this.method,
    this.meta = const [],
    this.subRoutes,
  });

  /// The route pattern, e.g. '/users/{id}'.
  final String pattern;

  /// HTTP method registered on this route.
  /// A null value means "all methods".
  final HttpMethod? method;

  /// Arbitrary metadata objects attached to this route.
  /// Retrieve by type via [metaOf] or [metaAll].
  final List<Object> meta;

  /// Nested sub-routes, if this route contains a mounted sub-router.
  final Routes? subRoutes;

  /// Returns the first meta object of type [T], or null if not found.
  T? metaOf<T extends Object>() {
    for (final a in meta) {
      if (a is T) return a;
    }
    return null;
  }

  /// Returns all meta objects of type [T].
  List<T> metaAll<T extends Object>() {
    return [
      for (final a in meta)
        if (a is T) a,
    ];
  }
}

/// Interface for introspecting the routing tree.
///
/// Allows traversal of registered routes without executing handlers.
/// Useful for documentation generation, OpenAPI specs, etc.
abstract interface class Routes {
  /// Returns all registered routes.
  List<Route> routes();

  /// Returns the list of middlewares in use by the router.
  List<Middleware> middlewares();

  /// Checks whether a handler exists for the given [method] and [path].
  /// Does not execute the handler.
  bool match(HttpMethod method, String path);

  /// Searches for the route pattern matching the given [method] and [path].
  /// Returns the matched pattern (e.g. '/users/{id}') or null.
  String? find(HttpMethod method, String path);
}

/// Callback for route tree traversal.
typedef RouteWalkFn =
    void Function(
      HttpMethod method,
      String fullRoute,
      List<Middleware> middlewares,
      List<Object> meta,
    );

/// Extension for walking the route tree.
extension RoutesWalk on Routes {
  /// Recursively walks all routes.
  ///
  /// Flattens sub-routers, concatenates patterns and middlewares.
  void walk(RouteWalkFn fn) {
    _walkRoutes(this, fn, '', []);
  }
}

void _walkRoutes(
  Routes router,
  RouteWalkFn fn,
  String parentRoute,
  List<Middleware> parentMw,
) {
  for (final route in router.routes()) {
    final mws = [...parentMw, ...router.middlewares()];

    if (route.subRoutes != null) {
      _walkRoutes(route.subRoutes!, fn, parentRoute + route.pattern, mws);
      continue;
    }

    if (route.method case final method?) {
      var fullRoute = parentRoute + route.pattern;
      while (fullRoute.contains('/*/')) {
        fullRoute = fullRoute.replaceAll('/*/', '/');
      }
      fn(method, fullRoute, mws, route.meta);
    }
  }
}

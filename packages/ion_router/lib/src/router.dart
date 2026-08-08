import 'dart:async';

import 'package:ion_router/src/context.dart';
import 'package:ion_router/src/middleware.dart';
import 'package:ion_router/src/route.dart';
import 'package:ion_router/src/tree.dart';
import 'package:ion_web/ion_web.dart';

/// HTTP router for ion_web.
abstract interface class Router implements Routes {
  factory Router() = IonRouter;

  /// Appends one or more middlewares onto the router stack.
  void use(Middleware middleware);

  /// Creates an inline router with additional middlewares.
  Router withMiddleware(Middleware middleware);

  /// Creates a new inline group with a shared middleware stack.
  Router group(void Function(Router r)? fn);

  /// Creates a sub-router mounted along the [pattern] path.
  Router route(String pattern, void Function(Router r) fn);

  /// Mounts a handler along [pattern], stripping the prefix
  /// before passing requests to the handler.
  void mount(String pattern, Handler handler);

  /// Merges another router's routes into this router.
  ///
  /// The merged router's routes (including their full patterns) are
  /// registered directly in this router's tree, making them visible
  /// to [routes] and [walk] for introspection.
  void merge(Router other);

  /// Registers a handler for a specific HTTP method and pattern.
  void on(
    HttpMethod? method,
    String pattern,
    Handler handler, {
    List<Object> meta,
  });

  /// HTTP method shortcuts
  void get(String pattern, Handler handler, {List<Object> meta});
  void post(String pattern, Handler handler, {List<Object> meta});
  void put(String pattern, Handler handler, {List<Object> meta});
  void delete(String pattern, Handler handler, {List<Object> meta});
  void patch(String pattern, Handler handler, {List<Object> meta});
  void head(String pattern, Handler handler, {List<Object> meta});
  void options(String pattern, Handler handler, {List<Object> meta});
  void connect(String pattern, Handler handler, {List<Object> meta});
  void trace(String pattern, Handler handler, {List<Object> meta});
  void query(String pattern, Handler handler, {List<Object> meta});
  void all(String pattern, Handler handler, {List<Object> meta});

  /// Custom 404 Not Found handler.
  void notFound(Handler handler);

  /// Custom 405 Method Not Allowed handler.
  void methodNotAllowed(Handler handler);

  /// Makes the Router callable as an ion_web [Handler].
  FutureOr<Response> call(Request req);
}

/// Default implementation of [Router] using a Radix Trie.
class IonRouter implements Router {
  IonRouter() : this._(inline: false, prefix: '');

  IonRouter._({
    required this.inline,
    this.prefix = '',
    List<Middleware>? middlewares,
    RouteNode? tree,
  }) : _middlewares = middlewares ?? [],
       _tree = tree ?? RouteNode();

  final bool inline;
  final String prefix;
  final List<Middleware> _middlewares;
  final RouteNode _tree;

  bool _locked = false;
  Handler? _computedHandler;
  Handler? _notFoundHandler;
  Handler? _methodNotAllowedHandler;

  @override
  void use(Middleware middleware) {
    if (_locked || _computedHandler != null) {
      throw StateError('all middlewares must be defined before routes');
    }
    _middlewares.add(middleware);
  }

  void _lock() {
    _locked = true;
    if (!inline && _computedHandler == null) {
      _updateRouteHandler();
    }
  }

  IonRouter _createInline() {
    _lock();
    final mws = inline ? List<Middleware>.from(_middlewares) : <Middleware>[];
    return IonRouter._(
      inline: true,
      prefix: prefix,
      middlewares: mws,
      tree: _tree,
    );
  }

  @override
  Router withMiddleware(Middleware middleware) {
    final im = _createInline();
    im._middlewares.add(middleware);
    return im;
  }

  @override
  Router group(void Function(Router r)? fn) {
    final im = _createInline();
    fn?.call(im);
    return im;
  }

  @override
  Router route(String pattern, void Function(Router r) fn) {
    _lock();
    final subPath = _joinPath(prefix, pattern);
    final mws = inline ? List<Middleware>.from(_middlewares) : <Middleware>[];
    final subRouter = IonRouter._(
      inline: true,
      prefix: subPath,
      middlewares: mws,
      tree: _tree,
    );
    fn(subRouter);
    return subRouter;
  }

  @override
  void mount(String pattern, Handler handler) {
    _lock();

    var p = _joinPath(prefix, pattern);
    if (p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }

    if (_tree.findPattern('$p*') || _tree.findPattern('$p/*')) {
      throw ArgumentError("attempting to mount handler on existing path '$p'");
    }

    FutureOr<Response> mountHandler(Request req) {
      final rctx = req.routeContext ?? RouteContext();
      rctx.routePath = _nextRoutePath(rctx);
      return handler.call(req);
    }

    if (p.isEmpty) {
      on(null, '/', mountHandler);
      p = '/';
    } else if (!p.endsWith('/')) {
      on(null, p, mountHandler);
      on(null, '$p/', mountHandler);
      p = '$p/';
    }

    final h = inline
        ? _chainMiddlewares(_middlewares, mountHandler)
        : mountHandler;
    _tree.insertRoute(null, '$p*', h);
  }

  @override
  void merge(Router other) {
    if (other is! IonRouter) {
      throw ArgumentError('merge requires an IonRouter instance');
    }

    _lock();

    other._tree.walkNodes((eps, subroutes) {
      for (final entry in eps.entries) {
        final method = entry.key;
        final ep = entry.value;
        if (ep.pattern.isEmpty) continue;

        // Wrap with the sub-router's middlewares since they won't be
        // applied through the sub-router's _computedHandler anymore.
        final wrapped = _chainMiddlewares(other._middlewares, ep.handler);
        final node = _tree.insertRoute(
          method,
          ep.pattern,
          wrapped,
          meta: ep.meta,
        );

        // Propagate subroutes for introspection (if the sub-router
        // itself has mount()-ed sub-routers inside).
        if (subroutes != null) {
          node.subroutes = subroutes;
        }
      }
    });
  }

  @override
  void on(
    HttpMethod? method,
    String pattern,
    Handler handler, {
    List<Object> meta = const [],
  }) {
    final fullPattern = _joinPath(prefix, pattern);
    if (fullPattern.isEmpty || !fullPattern.startsWith('/')) {
      throw ArgumentError(
        "routing pattern must begin with '/' in '$fullPattern'",
      );
    }

    _lock();

    final h = inline ? _chainMiddlewares(_middlewares, handler) : handler;

    _tree.insertRoute(method, fullPattern, h, meta: meta);
  }

  @override
  void get(String pattern, Handler handler, {List<Object> meta = const []}) {
    on(.get, pattern, handler, meta: meta);
  }

  @override
  void post(String pattern, Handler handler, {List<Object> meta = const []}) {
    on(.post, pattern, handler, meta: meta);
  }

  @override
  void put(String pattern, Handler handler, {List<Object> meta = const []}) {
    on(.put, pattern, handler, meta: meta);
  }

  @override
  void delete(String pattern, Handler handler, {List<Object> meta = const []}) {
    on(.delete, pattern, handler, meta: meta);
  }

  @override
  void patch(String pattern, Handler handler, {List<Object> meta = const []}) {
    on(.patch, pattern, handler, meta: meta);
  }

  @override
  void head(String pattern, Handler handler, {List<Object> meta = const []}) {
    on(.head, pattern, handler, meta: meta);
  }

  @override
  void options(
    String pattern,
    Handler handler, {
    List<Object> meta = const [],
  }) {
    on(.options, pattern, handler, meta: meta);
  }

  @override
  void connect(
    String pattern,
    Handler handler, {
    List<Object> meta = const [],
  }) {
    on(.connect, pattern, handler, meta: meta);
  }

  @override
  void trace(String pattern, Handler handler, {List<Object> meta = const []}) {
    on(.trace, pattern, handler, meta: meta);
  }

  @override
  void query(String pattern, Handler handler, {List<Object> meta = const []}) {
    on(.query, pattern, handler, meta: meta);
  }

  @override
  void all(String pattern, Handler handler, {List<Object> meta = const []}) {
    on(null, pattern, handler, meta: meta);
  }

  @override
  void notFound(Handler handler) {
    _notFoundHandler = handler;
  }

  @override
  void methodNotAllowed(Handler handler) {
    _methodNotAllowedHandler = handler;
  }

  @override
  List<Route> routes() => _tree.routes();

  @override
  List<Middleware> middlewares() => List.unmodifiable(_middlewares);

  @override
  bool match(HttpMethod method, String path) {
    return find(method, path) != null;
  }

  @override
  String? find(HttpMethod method, String path) {
    final rctx = RouteContext();
    final node = _tree.findRoute(rctx, method, path);
    if (node == null) return null;
    final ep = node.getEndpoint(method);
    return ep?.pattern;
  }

  @override
  FutureOr<Response> call(Request req) {
    var rctx = req.routeContext;
    final isRoot = rctx == null;

    rctx ??= RouteContext();
    final reqWithCtx = isRoot ? req.withRouteContext(rctx) : req;

    _computedHandler ??= _updateRouteHandler();
    return _computedHandler!(reqWithCtx);
  }

  FutureOr<Response> _routeRequest(Request req) {
    final rctx = req.routeContext!;
    var routePath = rctx.routePath;
    if (routePath.isEmpty) {
      routePath = req.uri.path;
      if (routePath.isEmpty) routePath = '/';
    }

    final node = _tree.findRoute(rctx, req.method, routePath);
    if (node != null) {
      final ep = node.getEndpoint(req.method);
      if (ep != null) {
        return ep.handler(req);
      }
    }

    if (rctx.methodNotAllowed) {
      return _handleMethodNotAllowed(req, rctx.methodsAllowed);
    }
    return _handleNotFound(req);
  }

  Handler _updateRouteHandler() {
    _computedHandler = _chainMiddlewares(_middlewares, _routeRequest);
    return _computedHandler!;
  }

  FutureOr<Response> _handleNotFound(Request req) {
    if (_notFoundHandler != null) {
      return _notFoundHandler!(req);
    }

    return const .status(.notFound);
  }

  FutureOr<Response> _handleMethodNotAllowed(
    Request req,
    Set<HttpMethod> allowed,
  ) {
    if (_methodNotAllowedHandler != null) {
      return _methodNotAllowedHandler!(req);
    }

    final allowHeaderValue = allowed.map((m) => m.value).join(', ');
    final headers = <TypedHeader>[];
    if (allowHeaderValue.isNotEmpty) {
      headers.add(.allow([allowHeaderValue]));
    }

    return .status(.methodNotAllowed, headers: headers);
  }

  String _nextRoutePath(RouteContext rctx) {
    var routePath = '/';
    final params = rctx.paramsNode;
    if (params != null && params.name == '*') {
      routePath = '/${params.value}';
    }
    return routePath;
  }

  String _joinPath(String p1, String p2) {
    if (p1.isEmpty || p1 == '/') return p2.startsWith('/') ? p2 : '/$p2';
    final cleanP1 = p1.endsWith('/') ? p1.substring(0, p1.length - 1) : p1;
    if (p2 == '/') return cleanP1;
    final cleanP2 = p2.startsWith('/') ? p2 : '/$p2';
    return cleanP1 + cleanP2;
  }

  Handler _chainMiddlewares(List<Middleware> middlewares, Handler endpoint) {
    if (middlewares.isEmpty) {
      return endpoint;
    }

    var handler = endpoint;
    for (var i = middlewares.length - 1; i >= 0; i--) {
      handler = middlewares[i](handler);
    }
    return handler;
  }
}

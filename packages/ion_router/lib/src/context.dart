import 'dart:collection';

import 'package:ctx/ctx.dart';
import 'package:ion_web/ion_web.dart';
import 'package:meta/meta.dart';

const _routeCtxKey = #routeContext;

@internal
class PathParams extends MapBase<String, String> {
  const PathParams(this.name, this.value, [this.next]);

  final String name;
  final String value;
  final PathParams? next;

  @override
  String? operator [](Object? key) {
    PathParams? current = this;
    while (current != null) {
      if (current.name == key) return current.value;
      current = current.next;
    }
    return null;
  }

  @override
  bool containsKey(Object? key) {
    PathParams? current = this;
    while (current != null) {
      if (current.name == key) return true;
      current = current.next;
    }
    return false;
  }

  @override
  void forEach(void Function(String key, String value) action) {
    PathParams? current = this;
    while (current != null) {
      action(current.name, current.value);
      current = current.next;
    }
  }

  @override
  bool containsValue(Object? value) {
    PathParams? current = this;
    while (current != null) {
      if (current.value == value) return true;
      current = current.next;
    }
    return false;
  }

  @override
  Iterable<String> get keys sync* {
    PathParams? current = this;
    while (current != null) {
      yield current.name;
      current = current.next;
    }
  }

  @override
  Iterable<String> get values sync* {
    PathParams? current = this;
    while (current != null) {
      yield current.value;
      current = current.next;
    }
  }

  @override
  int get length {
    var count = 0;
    PathParams? current = this;
    while (current != null) {
      count++;
      current = current.next;
    }
    return count;
  }

  @override
  bool get isEmpty => false;

  @override
  bool get isNotEmpty => true;

  @override
  void operator []=(String key, String value) {
    throw UnsupportedError('PathParams is unmodifiable');
  }

  @override
  void clear() {
    throw UnsupportedError('PathParams is unmodifiable');
  }

  @override
  String? remove(Object? key) {
    throw UnsupportedError('PathParams is unmodifiable');
  }
}

/// Routing context to track URL parameters, route patterns, and sub-router
/// state.
@internal
class RouteContext {
  RouteContext();

  /// Linked list of URL parameters captured during routing.
  PathParams? paramsNode;

  /// Routing path override used during sub-router search.
  String routePath = '';

  /// Stack of matching route patterns across nested routers.
  final List<String> routePatterns = [];

  /// HTTP methods allowed when path matches but method does not (for 405).
  final Set<HttpMethod> methodsAllowed = {};
  bool methodNotAllowed = false;

  /// Gets a parameter value by key.
  String? urlParam(String key) => paramsNode?[key];

  /// Returns map of all captured URL parameters.
  Map<String, String> get params => paramsNode ?? const {};

  /// Builds full route pattern string.
  String fullRoutePattern() {
    var pattern = routePatterns.join();
    while (pattern.contains('/*/') || pattern.contains('//')) {
      pattern = pattern.replaceAll('/*/', '/').replaceAll('//', '/');
    }
    if (pattern.length > 1 && pattern.endsWith('/')) {
      pattern = pattern.substring(0, pattern.length - 1);
    }
    return pattern;
  }
}

/// Public extensions on [Request] for accessing route parameters and patterns.
extension IonRouterRequest on Request {
  /// Gets all captured URL parameters.
  Map<String, String> get params => routeContext?.params ?? const {};

  /// Gets a specific URL parameter by name.
  String? param(String key) => routeContext?.urlParam(key);

  /// Gets a specific URL parameter by name and parses it.
  ///
  /// ```dart
  /// final id = req.parseParam('id', int.tryParse);
  /// ```
  T? parseParam<T>(
    String key,
    T? Function(String value) parse,
  ) {
    final value = param(key);
    return value != null ? parse(value) : null;
  }

  /// Gets the matched route pattern.
  String get routePattern => routeContext?.fullRoutePattern() ?? '';

  /// Gets the [RouteContext] from request context if present.
  @internal
  RouteContext? get routeContext => ctx.value(_routeCtxKey) as RouteContext?;

  /// Attach a [RouteContext] to request context.
  @internal
  Request withRouteContext(RouteContext rctx) {
    return copyWith(ctx: ctx.withValue(_routeCtxKey, rctx));
  }
}

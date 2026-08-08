import 'package:ion_router/src/context.dart';
import 'package:ion_router/src/route.dart';
import 'package:ion_router/src/router.dart';
import 'package:ion_web/ion_web.dart';
import 'package:meta/meta.dart';

final _asciiChars = List<String>.generate(256, String.fromCharCode);

const _codeOpenBrace = 123; // '{'
const _codeCloseBrace = 125; // '}'
const _codeAsterisk = 42; // '*'
const _codeSlash = 47; // '/'

@internal
enum RouteNodeType { static, param, catchAll }

@internal
class Endpoint {
  Endpoint({
    required this.handler,
    required this.pattern,
    this.meta = const [],
  });

  final Handler handler;
  final String pattern;
  final List<Object> meta;
}

@internal
class RouteNode {
  RouteNode({
    this.type = .static,
    this.prefix = '',
    this.label = 0,
    this.tail = 0,
    this.paramKey,
  });

  /// Reference to a mounted sub-router's [Routes] for introspection.
  /// Set by [IonRouter.mount] when the handler implements [Routes].
  Routes? subroutes;

  RouteNodeType type;
  String prefix;
  int label;
  int tail; // char code of tail delimiter (e.g. '/' or 0)
  String? paramKey;

  final Map<HttpMethod?, Endpoint> endpoints = {};

  final List<RouteNode> staticChildren = [];
  final List<RouteNode> paramChildren = [];
  final List<RouteNode> catchAllChildren = [];

  bool get isLeaf => endpoints.isNotEmpty;

  Endpoint? getEndpoint(HttpMethod? method) {
    var ep = endpoints[method] ?? endpoints[null];
    if (ep == null && method == .head) {
      ep = endpoints[HttpMethod.get];
    }
    return ep;
  }

  RouteNode insertRoute(
    HttpMethod? method,
    String pattern,
    Handler handler, {
    List<Object> meta = const [],
  }) {
    var n = this;
    var search = pattern;

    while (true) {
      if (search.isEmpty) {
        n._setEndpoint(method, handler, pattern, meta);
        return n;
      }

      final label = search.codeUnitAt(0);
      var segTail = 0;
      var segEndIdx = 0;
      var segTyp = RouteNodeType.static;
      String? pKey;

      if (label == _codeOpenBrace || label == _codeAsterisk) {
        final seg = _patNextSegment(search);
        segTyp = seg.type;
        segTail = seg.tail;
        segEndIdx = seg.endIdx;
        pKey = seg.key;
      }

      final parent = n;
      final childNode = n._getEdge(segTyp, label, segTail);

      if (childNode == null) {
        final child = RouteNode(
          label: label,
          tail: segTail,
          prefix: search,
          paramKey: pKey,
        );
        final hn = parent._addChild(child, search);
        hn._setEndpoint(method, handler, pattern, meta);
        return hn;
      }

      n = childNode;

      if (n.type != .static) {
        search = search.substring(segEndIdx);
        continue;
      }

      final commonPrefix = _longestPrefix(search, n.prefix);
      if (commonPrefix == n.prefix.length) {
        search = search.substring(commonPrefix);
        continue;
      }

      // Split the static node
      final child = RouteNode(
        label: search.codeUnitAt(0),
        prefix: search.substring(0, commonPrefix),
      );
      parent._replaceChild(search.codeUnitAt(0), segTail, child);

      n.label = n.prefix.codeUnitAt(commonPrefix);
      n.prefix = n.prefix.substring(commonPrefix);
      child._addChild(n, n.prefix);

      search = search.substring(commonPrefix);
      if (search.isEmpty) {
        child._setEndpoint(method, handler, pattern, meta);
        return child;
      }

      final subchild = RouteNode(
        label: search.codeUnitAt(0),
        prefix: search,
        paramKey: pKey,
      );
      final hn = child._addChild(subchild, search);
      hn._setEndpoint(method, handler, pattern, meta);
      return hn;
    }
  }

  RouteNode? findRoute(RouteContext rctx, HttpMethod method, String path) {
    final prevParams = rctx.paramsNode;

    final rn = _findRouteRecursive(rctx, method, path, 0);
    if (rn == null) {
      rctx.paramsNode = prevParams;
      return null;
    }

    final ep = rn.getEndpoint(method);
    if (ep != null && ep.pattern.isNotEmpty) {
      rctx.routePatterns.add(ep.pattern);
    }

    return rn;
  }

  RouteNode? _findRouteRecursive(
    RouteContext rctx,
    HttpMethod method,
    String path,
    int offset,
  ) {
    final label = offset < path.length ? path.codeUnitAt(offset) : 0;

    // Static children search
    if (staticChildren.isNotEmpty) {
      for (var i = 0; i < staticChildren.length; i++) {
        final xn = staticChildren[i];
        if (xn.label != label || !path.startsWith(xn.prefix, offset)) {
          continue;
        }

        final nextOffset = offset + xn.prefix.length;
        if (nextOffset == path.length) {
          if (xn.isLeaf) {
            final ep = xn.getEndpoint(method);
            if (ep != null) {
              return xn;
            }
            for (final m in xn.endpoints.keys) {
              if (m != null) rctx.methodsAllowed.add(m);
            }
            rctx.methodNotAllowed = true;
          }
          final fin = xn._findRouteRecursive(rctx, method, path, nextOffset);
          if (fin != null) return fin;
        } else {
          final fin = xn._findRouteRecursive(rctx, method, path, nextOffset);
          if (fin != null) return fin;
        }
      }
    }

    // Param children search
    if (paramChildren.isNotEmpty && offset < path.length) {
      for (var i = 0; i < paramChildren.length; i++) {
        final xn = paramChildren[i];
        var p = xn.tail != 0 ? path.indexOf(_asciiChars[xn.tail], offset) : -1;

        if (p < 0) {
          if (xn.tail == _codeSlash || xn.tail == 0) {
            // '/' (47) or 0
            p = path.length;
          } else {
            continue;
          }
        }

        final slashIdx = path.indexOf('/', offset);
        if (slashIdx >= 0 && slashIdx < p) continue;

        final paramVal = path.substring(offset, p);
        final prevParams = rctx.paramsNode;
        rctx.paramsNode = PathParams(
          xn.paramKey ?? 'param',
          paramVal,
          prevParams,
        );

        if (p == path.length) {
          if (xn.isLeaf) {
            final ep = xn.getEndpoint(method);
            if (ep != null) {
              return xn;
            }
            for (final m in xn.endpoints.keys) {
              if (m != null) rctx.methodsAllowed.add(m);
            }
            rctx.methodNotAllowed = true;
          }
        } else {
          final fin = xn._findRouteRecursive(rctx, method, path, p);
          if (fin != null) return fin;
        }

        rctx.paramsNode = prevParams;
      }
    }

    // CatchAll children search
    if (catchAllChildren.isNotEmpty) {
      final xn = catchAllChildren.first;
      final paramVal = path.substring(offset);
      rctx.paramsNode = PathParams('*', paramVal, rctx.paramsNode);

      if (xn.isLeaf) {
        final ep = xn.getEndpoint(method);
        if (ep != null) {
          return xn;
        }
        for (final m in xn.endpoints.keys) {
          if (m != null) rctx.methodsAllowed.add(m);
        }
        rctx.methodNotAllowed = true;
      }
      final fin = xn._findRouteRecursive(rctx, method, path, path.length);
      if (fin != null) return fin;
    }

    return null;
  }

  RouteNode _addChild(RouteNode child, String prefix) {
    var search = prefix;
    var hn = child;

    final seg = _patNextSegment(search);
    if (seg.type != .static) {
      if (seg.startIdx == 0) {
        child.type = seg.type;
        child.paramKey = seg.key;
        var startIdx = seg.type == .catchAll ? -1 : seg.endIdx;
        if (startIdx < 0) startIdx = search.length;
        child.tail = seg.tail;

        if (startIdx != search.length) {
          search = search.substring(startIdx);
          final nn = RouteNode(
            label: search.codeUnitAt(0),
            prefix: search,
          );
          hn = child._addChild(nn, search);
        }
      } else if (seg.startIdx > 0) {
        child.type = .static;
        child.prefix = search.substring(0, seg.startIdx);

        search = search.substring(seg.startIdx);
        final nn = RouteNode(
          type: seg.type,
          label: search.codeUnitAt(0),
          tail: seg.tail,
          paramKey: seg.key,
        );
        hn = child._addChild(nn, search);
      }
    }

    final list = _getChildrenList(child.type);
    list.add(child);
    _sortNodes(list);
    return hn;
  }

  List<RouteNode> _getChildrenList(RouteNodeType type) {
    return switch (type) {
      .static => staticChildren,
      .param => paramChildren,
      .catchAll => catchAllChildren,
    };
  }

  RouteNode? _getEdge(RouteNodeType ntyp, int label, int tail) {
    final nds = _getChildrenList(ntyp);
    for (var i = 0; i < nds.length; i++) {
      final child = nds[i];
      if (child.label == label && child.tail == tail) {
        return child;
      }
    }
    return null;
  }

  void _replaceChild(int label, int tail, RouteNode child) {
    final list = _getChildrenList(child.type);
    for (var i = 0; i < list.length; i++) {
      if (list[i].label == label && list[i].tail == tail) {
        list[i] = child;
        return;
      }
    }
    throw StateError('replacing missing child');
  }

  void _setEndpoint(
    HttpMethod? method,
    Handler handler,
    String pattern,
    List<Object> meta,
  ) {
    _patParamKeys(pattern);
    endpoints[method] = Endpoint(
      handler: handler,
      pattern: pattern,
      meta: meta,
    );
  }

  /// Collects all routes from the tree into a flat list of [Route].
  List<Route> routes() {
    final result = <Route>[];

    walkNodes((eps, subroutes) {
      if (subroutes != null) {
        for (final entry in eps.entries) {
          final ep = entry.value;
          if (ep.pattern.isEmpty) continue;

          result.add(
            Route(
              pattern: ep.pattern,
              method: entry.key,
              meta: ep.meta,
              subRoutes: subroutes,
            ),
          );
        }
        return;
      }

      for (final entry in eps.entries) {
        final ep = entry.value;
        if (ep.pattern.isEmpty) continue;

        result.add(
          Route(
            pattern: ep.pattern,
            method: entry.key,
            meta: ep.meta,
          ),
        );
      }
    });

    return result;
  }

  @internal
  void walkNodes(
    void Function(Map<HttpMethod?, Endpoint> endpoints, Routes? subroutes) fn,
  ) {
    if (endpoints.isNotEmpty || subroutes != null) {
      fn(endpoints, subroutes);
    }
    for (final child in [
      ...staticChildren,
      ...paramChildren,
      ...catchAllChildren,
    ]) {
      child.walkNodes(fn);
    }
  }

  void _sortNodes(List<RouteNode> list) {
    list.sort((a, b) {
      if (a.tail == _codeSlash && b.tail != _codeSlash) return 1;
      if (a.tail != _codeSlash && b.tail == _codeSlash) return -1;
      return a.label.compareTo(b.label);
    });
  }

  bool findPattern(String pattern) {
    if (pattern.isEmpty) return false;

    final firstChar = pattern.codeUnitAt(0);
    final child =
        _getEdge(.static, firstChar, 0) ??
        _getEdge(.param, firstChar, 0) ??
        _getEdge(.catchAll, firstChar, 0);

    if (child == null) return false;

    var idx = 0;
    switch (child.type) {
      case .static:
        idx = _longestPrefix(pattern, child.prefix);
        if (idx < child.prefix.length) return false;
      case .param:
        idx = pattern.indexOf('}') + 1;
        if (idx <= 0) return false;
      case .catchAll:
        idx = _longestPrefix(pattern, '*');
    }

    final xpattern = pattern.substring(idx);
    if (xpattern.isEmpty) return true;
    return child.findPattern(xpattern);
  }

  List<String> _patParamKeys(String pattern) {
    var pat = pattern;
    final keys = <String>[];
    while (true) {
      final seg = _patNextSegment(pat);
      if (seg.type == .static) return keys;
      if (keys.contains(seg.key)) {
        throw ArgumentError("duplicate param key '${seg.key}' in '$pattern'");
      }
      keys.add(seg.key);
      pat = pat.substring(seg.endIdx);
    }
  }

  int _longestPrefix(String k1, String k2) {
    final maxLen = k1.length < k2.length ? k1.length : k2.length;
    for (var i = 0; i < maxLen; i++) {
      if (k1.codeUnitAt(i) != k2.codeUnitAt(i)) return i;
    }
    return maxLen;
  }
}

class _Segment {
  _Segment(this.type, this.key, this.tail, this.startIdx, this.endIdx);

  final RouteNodeType type;
  final String key;
  final int tail;
  final int startIdx;
  final int endIdx;
}

_Segment _patNextSegment(String pattern) {
  final ps = pattern.indexOf('{');
  final ws = pattern.indexOf('*');

  if (ps < 0 && ws < 0) {
    return _Segment(.static, '', 0, 0, pattern.length);
  }

  if (ps >= 0 && ws >= 0 && ws < ps) {
    throw ArgumentError("wildcard '*' must be the last pattern in a route");
  }

  var tail = _codeSlash;

  if (ps >= 0) {
    var cc = 0;
    var pe = ps;
    for (var i = ps; i < pattern.length; i++) {
      final c = pattern.codeUnitAt(i);
      if (c == _codeOpenBrace) {
        cc++;
      } else if (c == _codeCloseBrace) {
        cc--;
        if (cc == 0) {
          pe = i;
          break;
        }
      }
    }
    if (pe == ps) {
      throw ArgumentError("route param closing delimiter '}' missing");
    }

    final key = pattern.substring(ps + 1, pe);
    pe++;

    if (pe < pattern.length) {
      tail = pattern.codeUnitAt(pe);
    }

    return _Segment(.param, key, tail, ps, pe);
  }

  if (ws < pattern.length - 1) {
    throw ArgumentError("wildcard '*' must be the last value in a route");
  }
  return _Segment(.catchAll, '*', 0, ws, pattern.length);
}

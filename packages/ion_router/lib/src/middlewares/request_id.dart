import 'dart:math';

import 'package:ctx/ctx.dart';
import 'package:ion_router/src/middleware.dart';
import 'package:ion_web/ion_web.dart';

const _requestIdCtxKey = #requestId;

/// A [TypedHeader] representing an `X-Request-Id` (or custom request ID)
/// header.
final class RequestIdHeader implements TypedHeader {
  const RequestIdHeader(this.id, {this.name = 'X-Request-Id'});

  final String id;

  @override
  final String name;

  @override
  Iterable<String> encode() => [id];

  @override
  String toString() => '$name: $id';

  /// Decodes [values] into a [RequestIdHeader].
  static RequestIdHeader? decode(
    Iterable<String> values, {
    String name = 'X-Request-Id',
  }) {
    final val = values.firstOrNull;
    if (val == null || val.isEmpty) return null;
    return RequestIdHeader(val, name: name);
  }
}

/// Extension on [Context] to access the request ID.
extension RequestIdContext on Context {
  /// Gets the request ID associated with this context, if present.
  String? get requestId => value(_requestIdCtxKey) as String?;
}

final String _processPrefix = _initProcessPrefix();
int _reqIdCounter = 0;

String _initProcessPrefix() {
  final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final rand = Random().nextInt(0xFFFFFF).toRadixString(36);
  return '$now-$rand';
}

String _defaultIdGenerator() {
  return '$_processPrefix-${_reqIdCounter++}';
}

/// Creates a [Middleware] that injects a request ID into the request context
/// and sets the request ID header on the returned [Response].
Middleware requestIdMiddleware({
  String headerName = 'X-Request-Id',
  String Function()? idGenerator,
}) {
  final generateId = idGenerator ?? _defaultIdGenerator;

  return (Handler next) {
    return (Request req) async {
      final existingHeader = req.headers.decode(
        HttpHeader(headerName),
        (values) => RequestIdHeader.decode(values, name: headerName),
      );
      final id = existingHeader?.id ?? generateId();

      final updatedReq = req.copyWith(
        ctx: req.ctx.withValue(_requestIdCtxKey, id),
      );

      final response = await next(updatedReq);
      return response.withHeaders([RequestIdHeader(id, name: headerName)]);
    };
  };
}

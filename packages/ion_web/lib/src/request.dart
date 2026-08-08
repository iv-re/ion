import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ctx/ctx.dart';
import 'package:ion_web/src/http/http.dart';

class Request extends StreamView<Uint8List> {
  const Request(
    super.stream, {
    required this.method,
    required this.uri,
    required this.version,
    required this.headers,
    this.connectionInfo,
    this.ctx = const .empty(),
  });

  final HttpMethod method;
  final Uri uri;
  final HttpVersion version;
  final TypedHeaders headers;
  final ConnectionInfo? connectionInfo;
  final Context ctx;

  Request copyWith({
    Stream<Uint8List>? body,
    HttpMethod? method,
    Uri? uri,
    TypedHeaders? headers,
    Context? ctx,
  }) {
    return Request(
      body ?? this,
      method: method ?? this.method,
      uri: uri ?? this.uri,
      version: version,
      headers: headers ?? this.headers,
      connectionInfo: connectionInfo,
      ctx: ctx ?? this.ctx,
    );
  }
}

extension RequestTextExtractor on Request {
  /// Reads the request body as a UTF-8 encoded string.
  ///
  /// This will consume the request body stream and return the decoded string.
  Future<String> text() => utf8.decodeStream(this);
}

extension Http1RequestKeepAlive on Request {
  /// Whether the underlying HTTP/1.1 connection requests keep-alive.
  bool get keepAlive {
    return switch (headers.connection) {
      final conn? when conn.isClose => false,
      final conn? when conn.isKeepAlive => true,
      _ => version == .http11,
    };
  }
}

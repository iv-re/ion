import 'dart:typed_data';

import 'package:ion_router/ion_router.dart';
import 'package:ion_web/ion_web.dart';

/// Helper function to perform requests against a [Router] in middleware tests.
Future<Response> makeRequest(
  Router app, {
  String path = '/',
  HttpMethod method = HttpMethod.get,
  Iterable<TypedHeader>? headers,
  Stream<Uint8List> body = const Stream.empty(),
}) async {
  final uriPath = path.startsWith('/') ? path : '/$path';
  return app(
    Request(
      body,
      method: method,
      uri: .parse('http://localhost$uriPath'),
      version: .http11,
      headers: .fromList(headers ?? const []),
    ),
  );
}

final class TestHeader implements TypedHeader {
  const TestHeader(this.name, this.value);

  @override
  final String name;
  final String value;

  @override
  Iterable<String> encode() => [value];
}

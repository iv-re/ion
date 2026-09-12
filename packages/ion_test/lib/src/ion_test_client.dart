import 'package:ion_test/src/test_body.dart';
import 'package:ion_web/ion_web.dart';

/// Client used inside `ionTest`'s `act` callback to execute requests
/// against a target handler or router.
class IonTestClient {
  /// Constructs an [IonTestClient] wrapping the target [handler].
  IonTestClient(
    this.handler, {
    String baseUrl = 'http://localhost',
  }) : baseUrl = Uri.parse(baseUrl);

  /// The target handler under test.
  final Handler handler;

  /// Base URI used for resolving relative request paths.
  final Uri baseUrl;

  /// Sends a raw [Request] directly through the handler.
  Future<Response> send(Request request) async {
    var response = await handler(request);
    while (response is ResolvableResponse) {
      final resResult = response.resolve(request);
      response = resResult is Response ? resResult : await resResult;
    }
    return response;
  }

  /// Performs a GET request.
  Future<Response> get(
    String path, {
    Map<String, String>? query,
    Iterable<TypedHeader>? headers,
  }) {
    return _request(.get, path, query: query, headers: headers);
  }

  /// Performs a HEAD request.
  Future<Response> head(
    String path, {
    Map<String, String>? query,
    Iterable<TypedHeader>? headers,
  }) {
    return _request(.head, path, query: query, headers: headers);
  }

  /// Performs an OPTIONS request.
  Future<Response> options(
    String path, {
    Map<String, String>? query,
    Iterable<TypedHeader>? headers,
  }) {
    return _request(.options, path, query: query, headers: headers);
  }

  /// Performs a POST request with optional [TestBody].
  Future<Response> post(
    String path, {
    Map<String, String>? query,
    TestBody body = const .empty(),
    Iterable<TypedHeader>? headers,
  }) {
    return _request(
      .post,
      path,
      query: query,
      body: body,
      headers: headers,
    );
  }

  /// Performs a PUT request with optional [TestBody].
  Future<Response> put(
    String path, {
    Map<String, String>? query,
    TestBody body = const .empty(),
    Iterable<TypedHeader>? headers,
  }) {
    return _request(
      .put,
      path,
      query: query,
      body: body,
      headers: headers,
    );
  }

  /// Performs a PATCH request with optional [TestBody].
  Future<Response> patch(
    String path, {
    Map<String, String>? query,
    TestBody body = const .empty(),
    Iterable<TypedHeader>? headers,
  }) {
    return _request(
      .patch,
      path,
      query: query,
      body: body,
      headers: headers,
    );
  }

  /// Performs a DELETE request with optional [TestBody].
  Future<Response> delete(
    String path, {
    Map<String, String>? query,
    TestBody body = const .empty(),
    Iterable<TypedHeader>? headers,
  }) {
    return _request(
      .delete,
      path,
      query: query,
      body: body,
      headers: headers,
    );
  }

  Future<Response> _request(
    HttpMethod method,
    String path, {
    Map<String, String>? query,
    TestBody body = const .empty(),
    Iterable<TypedHeader>? headers,
  }) {
    final (payloadBytes, defaultHeaders) = body.build();
    final requestHeaders = <TypedHeader>[
      ...defaultHeaders,
      ...?headers,
    ];

    final requestObj = Request(
      payloadBytes.isNotEmpty ? .value(payloadBytes) : const .empty(),
      method: method,
      uri: _resolveUri(path, query),
      version: .http11,
      headers: .fromList(requestHeaders),
    );

    return send(requestObj);
  }

  Uri _resolveUri(String path, Map<String, String>? query) {
    final uri = baseUrl.resolve(path);
    if (query == null || query.isEmpty) return uri;

    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        ...query,
      },
    );
  }
}

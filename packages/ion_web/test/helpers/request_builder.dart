// ignore_for_file: avoid_returning_this
import 'package:ion_web/ion_web.dart';
import 'bytes.dart';

/// Fluent builder for constructing [Request] objects in tests.
///
/// Usage:
/// ```dart
/// TestRequestBuilder.get('/path').headers([
///   const .host('example.com'),
/// ]).build()
/// TestRequestBuilder.post('/upload').bodyText('hello').build()
/// TestRequestBuilder.multipart(boundary: 'abc', body: bytes).build()
/// ```
class TestRequestBuilder {
  TestRequestBuilder._(this._method, [String? path]) : _path = path;

  /// GET request builder.
  factory TestRequestBuilder.get([String path = '/']) =>
      TestRequestBuilder._(HttpMethod.get, path);

  /// POST request builder.
  factory TestRequestBuilder.post([String path = '/']) =>
      TestRequestBuilder._(HttpMethod.post, path);

  /// HEAD request builder.
  factory TestRequestBuilder.head([String path = '/']) =>
      TestRequestBuilder._(HttpMethod.head, path);

  /// Multipart POST request builder — sets content-type with boundary,
  /// content-length, and body bytes in one shot.
  factory TestRequestBuilder.multipart({
    required String boundary,
    required List<int> body,
    String path = '/upload',
  }) {
    return TestRequestBuilder._(HttpMethod.post, path)
      .._headers.addAll([
        TypedHeader.contentType('multipart/form-data; boundary=$boundary'),
        TypedHeader.contentLength(body.length),
      ])
      .._bodyBytes = body;
  }

  final HttpMethod _method;
  String? _path;
  Uri? _uri;
  HttpVersion _version = HttpVersion.http11;
  final List<TypedHeader> _headers = [];
  Stream<Uint8List>? _bodyStream;
  List<int>? _bodyBytes;
  String? _bodyText;

  /// Sets the request path (e.g. '/upload').
  TestRequestBuilder path(String path) {
    _path = path;
    return this;
  }

  /// Sets the full request URI directly (overrides [path]).
  TestRequestBuilder uri(Uri uri) {
    _uri = uri;
    return this;
  }

  /// Adds typed headers to the request.
  TestRequestBuilder headers(List<TypedHeader> list) {
    _headers.addAll(list);
    return this;
  }

  /// Sets the HTTP version.
  TestRequestBuilder version(HttpVersion v) {
    _version = v;
    return this;
  }

  /// Sets the body as a raw byte stream.
  TestRequestBuilder bodyStream(Stream<Uint8List> stream) {
    _bodyStream = stream;
    return this;
  }

  /// Sets the body as raw bytes.
  TestRequestBuilder bodyBytes(List<int> bytes) {
    _bodyBytes = bytes;
    return this;
  }

  /// Sets the body as a UTF-8 text string.
  TestRequestBuilder bodyText(String text) {
    _bodyText = text;
    return this;
  }

  /// Builds the [Request].
  Request build() {
    Stream<Uint8List> stream;
    if (_bodyStream != null) {
      stream = _bodyStream!;
    } else if (_bodyBytes != null) {
      stream = Stream.value(Uint8List.fromList(_bodyBytes!));
    } else if (_bodyText != null) {
      stream = Stream.value(stringToBytes(_bodyText!));
    } else {
      stream = const Stream<Uint8List>.empty();
    }

    final h = _headers.isNotEmpty
        ? TypedHeaders.fromList(_headers)
        : TypedHeaders([]);

    Uri requestUri;
    if (_uri != null) {
      requestUri = _uri!;
    } else if (_path != null) {
      final p = _path!;
      requestUri = Uri.parse(
        p.startsWith('http://') || p.startsWith('https://')
            ? p
            : p.startsWith('/')
            ? 'http://localhost$p'
            : 'http://localhost/$p',
      );
    } else {
      requestUri = Uri.parse('http://localhost/');
    }

    return Request(
      stream,
      method: _method,
      uri: requestUri,
      version: _version,
      headers: h,
    );
  }
}

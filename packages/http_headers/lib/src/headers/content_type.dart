import 'package:equatable/equatable.dart';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';

/// The `Content-Type` header field,
/// defined in [RFC 7231 Section 3.1.1.5](https://datatracker.ietf.org/doc/html/rfc7231#section-3.1.1.5).
///
/// Indicates the media type of the underlying resource.
///
/// ```dart
/// final type = ContentTypeHeader.json();
/// final decoded = ContentTypeHeader.decode(['text/html; charset=utf-8']);
/// ```
final class ContentTypeHeader extends Equatable implements TypedHeader {
  /// Creates a `Content-Type` header with media type and optional parameters.
  const ContentTypeHeader(
    this.mediaType, {
    this.charset,
    this.boundary,
  }) : _encoded = null;

  /// Private constructor with pre-encoded header values.
  const ContentTypeHeader._(
    this.mediaType, {
    this.charset,
    this.boundary,
    this._encoded,
  });

  /// Creates `Content-Type: application/json`.
  const ContentTypeHeader.json()
    : this._('application/json', encoded: _jsonEncoded);

  /// Creates `Content-Type: application/json; charset=utf-8`.
  const ContentTypeHeader.jsonUtf8()
    : this._('application/json', charset: 'utf-8', encoded: _jsonUtf8Encoded);

  /// Creates `Content-Type: application/problem+json`.
  const ContentTypeHeader.jsonProblem()
    : this._('application/problem+json', encoded: _jsonProblemEncoded);

  /// Creates `Content-Type: text/event-stream`.
  const ContentTypeHeader.eventStream()
    : this._('text/event-stream', encoded: _eventStreamEncoded);

  /// Creates `Content-Type: application/x-ndjson`.
  const ContentTypeHeader.ndjson()
    : this._('application/x-ndjson', encoded: _ndjsonEncoded);

  /// Creates `Content-Type: text/plain`.
  const ContentTypeHeader.text() : this._('text/plain', encoded: _textEncoded);

  /// Creates `Content-Type: text/plain; charset=utf-8`.
  const ContentTypeHeader.textUtf8()
    : this._('text/plain', charset: 'utf-8', encoded: _textUtf8Encoded);

  /// Creates `Content-Type: text/html`.
  const ContentTypeHeader.html() : this._('text/html', encoded: _htmlEncoded);

  /// Creates `Content-Type: text/xml`.
  const ContentTypeHeader.xml() : this._('text/xml', encoded: _xmlEncoded);

  /// Creates `Content-Type: application/x-www-form-urlencoded`.
  const ContentTypeHeader.formUrlEncoded()
    : this._(
        'application/x-www-form-urlencoded',
        encoded: _formUrlEncoded,
      );

  /// Creates `Content-Type: multipart/form-data`.
  const ContentTypeHeader.multipartFormData({String? boundary})
    : this._(
        'multipart/form-data',
        boundary: boundary,
        encoded: boundary == null ? _multipartFormDataEncoded : null,
      );

  /// Creates `Content-Type: image/jpeg`.
  const ContentTypeHeader.jpeg() : this._('image/jpeg', encoded: _jpegEncoded);

  /// Creates `Content-Type: image/png`.
  const ContentTypeHeader.png() : this._('image/png', encoded: _pngEncoded);

  /// Creates `Content-Type: image/webp`.
  const ContentTypeHeader.webp() : this._('image/webp', encoded: _webpEncoded);

  /// Creates `Content-Type: image/svg+xml`.
  const ContentTypeHeader.svg() : this._('image/svg+xml', encoded: _svgEncoded);

  /// Creates `Content-Type: application/pdf`.
  const ContentTypeHeader.pdf()
    : this._('application/pdf', encoded: _pdfEncoded);

  /// Creates `Content-Type: application/octet-stream`.
  const ContentTypeHeader.octetStream()
    : this._('application/octet-stream', encoded: _octetStreamEncoded);

  /// Creates `Content-Type: application/x-protobuf`.
  const ContentTypeHeader.protobuf()
    : this._('application/x-protobuf', encoded: _protobufEncoded);

  /// Decodes this header type from raw header values.
  static ContentTypeHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    final raw = values.first.trim();
    if (raw.isEmpty) return null;

    final parts = raw.split(';');
    final mediaType = parts.first.trim().toLowerCase();
    if (mediaType.isEmpty) return null;

    String? charset;
    String? boundary;

    for (var i = 1; i < parts.length; i++) {
      final param = parts[i].trim();
      final eqIndex = param.indexOf('=');
      if (eqIndex != -1) {
        final key = param.substring(0, eqIndex).trim().toLowerCase();
        var val = param.substring(eqIndex + 1).trim();
        if (val.startsWith('"') && val.endsWith('"') && val.length >= 2) {
          val = val.substring(1, val.length - 1);
        }
        if (key == 'charset') {
          charset = val;
        } else if (key == 'boundary') {
          boundary = val;
        }
      }
    }

    return ContentTypeHeader(mediaType, charset: charset, boundary: boundary);
  }

  static const _jsonEncoded = ['application/json'];
  static const _jsonUtf8Encoded = ['application/json; charset=utf-8'];
  static const _jsonProblemEncoded = ['application/problem+json'];
  static const _eventStreamEncoded = ['text/event-stream'];
  static const _ndjsonEncoded = ['application/x-ndjson'];
  static const _textEncoded = ['text/plain'];
  static const _textUtf8Encoded = ['text/plain; charset=utf-8'];
  static const _htmlEncoded = ['text/html'];
  static const _xmlEncoded = ['text/xml'];
  static const _formUrlEncoded = ['application/x-www-form-urlencoded'];
  static const _multipartFormDataEncoded = ['multipart/form-data'];
  static const _jpegEncoded = ['image/jpeg'];
  static const _pngEncoded = ['image/png'];
  static const _webpEncoded = ['image/webp'];
  static const _svgEncoded = ['image/svg+xml'];
  static const _pdfEncoded = ['application/pdf'];
  static const _octetStreamEncoded = ['application/octet-stream'];
  static const _protobufEncoded = ['application/x-protobuf'];

  /// The media type (e.g. "application/json", "text/html").
  final String mediaType;

  /// The optional charset (e.g. "utf-8").
  final String? charset;

  /// The optional boundary parameter for multipart media types.
  final String? boundary;

  final Iterable<String>? _encoded;

  @override
  String get name => HttpHeader.contentType.name;

  @override
  Iterable<String> encode() {
    final encoded = _encoded;
    if (encoded != null) return encoded;
    final c = charset;
    final b = boundary;

    if (c == null && b == null) return [mediaType];
    if (b == null) return ['$mediaType; charset=$c'];
    if (c == null) return ['$mediaType; boundary=$b'];
    return ['$mediaType; charset=$c; boundary=$b'];
  }

  @override
  List<Object?> get props => [mediaType, charset, boundary];
}

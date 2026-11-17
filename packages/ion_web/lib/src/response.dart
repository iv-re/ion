import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ion_web/ion_web.dart';
import 'package:mime/mime.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Represents the body payload of a standard HTTP response.
sealed class ResponseBody {
  const ResponseBody._();

  const factory ResponseBody.empty() = EmptyResponseBody;

  const factory ResponseBody.bytes(Uint8List bytes) = BytesResponseBody;

  const factory ResponseBody.stream(
    Stream<Uint8List> stream, {
    int? contentLength,
  }) = StreamResponseBody;

  /// The length of the body in bytes, or `null` if unknown (chunked encoding).
  int? get contentLength;
}

final class EmptyResponseBody extends ResponseBody {
  const EmptyResponseBody() : super._();

  @override
  int? get contentLength => 0;
}

final class BytesResponseBody extends ResponseBody {
  const BytesResponseBody(this.bytes) : super._();

  final Uint8List bytes;

  @override
  int? get contentLength => bytes.length;
}

final class StreamResponseBody extends ResponseBody {
  const StreamResponseBody(this.stream, {this.contentLength}) : super._();

  final Stream<Uint8List> stream;

  @override
  final int? contentLength;
}

/// Callback invoked when an error occurs during Server-Sent Events (SSE)
/// streaming.
///
/// Returning a non-null [SseEvent] sends that event to the client before
/// the stream terminates cleanly. Returning `null` gracefully terminates
/// the stream without emitting any further events.
typedef SseErrorHandler =
    FutureOr<SseEvent?> Function(
      Object error,
      StackTrace stackTrace,
    );

class Response {
  const Response({
    required this.status,
    this.headers = const [],
    this.body = const .empty(),
    this.onUpgrade,
  });

  const Response.status(
    this.status, {
    this.headers = const [],
  }) : body = const .empty(),
       onUpgrade = null;

  Response.bytes(
    Uint8List bytes, {
    this.status = .ok,
    this.headers = const [],
  }) : body = .bytes(bytes),
       onUpgrade = null;

  Response.text(
    String data, {
    this.status = .ok,
    List<TypedHeader> headers = const [],
  }) : body = .bytes(utf8.encode(data)),
       headers = const <TypedHeader>[
         .contentType('text/plain', charset: 'utf-8'),
       ].replacing(headers),
       onUpgrade = null;

  Response.redirect(
    Uri location, {
    this.status = .found,
    List<TypedHeader> headers = const [],
  }) : body = const .empty(),
       headers = <TypedHeader>[
         .location(location.toString()),
       ].replacing(headers),
       onUpgrade = null;

  Response.stream(
    Stream<Uint8List> stream, {
    this.status = .ok,
    int? contentLength,
    this.headers = const [],
  }) : body = .stream(stream, contentLength: contentLength),
       onUpgrade = null;

  /// Creates a Server-Sent Events (SSE) streaming response.
  ///
  /// The [streamBuilder] is evaluated lazily when response transmission begins.
  /// Standard SSE response headers (`Content-Type: text/event-stream`,
  /// `Cache-Control: no-cache`) are set unless [headers] replaces them.
  ///
  /// If [onError] is provided, any synchronous exception thrown by
  /// [streamBuilder] or asynchronous error emitted by the resulting stream is
  /// passed to [onError]. If [onError] returns an [SseEvent], it is emitted to
  /// the client before the stream terminates cleanly. If it returns `null`,
  /// the stream closes gracefully. If [onError] is omitted, errors are
  /// rethrown, causing the connection to abort.
  Response.sse(
    Stream<SseEvent> Function() streamBuilder, {
    this.status = .ok,
    List<TypedHeader> headers = const [],
    SseErrorHandler? onError,
  }) : body = .stream(_deferSseStream(streamBuilder, onError)),
       headers = const <TypedHeader>[
         .contentType('text/event-stream'),
         .cacheControl(noCache: true),
       ].replacing(headers),
       onUpgrade = null;

  const Response.upgrade(
    this.onUpgrade, {
    this.status = .switchingProtocols,
    this.headers = const [],
    this.body = const .empty(),
  });

  const factory Response.websocket(
    FutureOr<void> Function(WebSocketChannel channel) handler, {
    String? Function(List<String> requestedProtocols)? protocolSelector,
    WebSocketDeflateOptions compression,
    List<TypedHeader> headers,
    int? maxMessageSize,
    bool Function(String? origin)? checkOrigin,
  }) = WebSocketResponse;

  /// Creates a response for serving static content (e.g., files, in-memory
  /// assets, or custom data streams).
  ///
  /// Automatically handles:
  /// - MIME type detection (by file extension in [name] or magic bytes sniff).
  /// - RFC 7232 HTTP Preconditions (`If-Match`, `If-None-Match`,
  ///   `If-Modified-Since`, `If-Unmodified-Since`, `If-Range`).
  /// - RFC 7233 Range requests (`206 Partial Content` and
  ///   `416 Range Not Satisfiable`).
  /// - `HEAD` requests without reading stream payload.
  ///
  /// Parameters:
  /// - [read]: A callback `(int start, int end)` that returns a [Stream] of
  ///   bytes starting at byte offset `start` up to `end` byte index
  ///   (exclusive).
  /// - [size]: The total size of the resource in bytes.
  /// - [name]: The file name or path (e.g., `'index.html'`), used for MIME
  ///   type lookup.
  /// - [lastModified]: The timestamp when the resource was last modified.
  /// - [headers]: Optional extra HTTP headers (e.g., ETag or Cache-Control).
  factory Response.content({
    required Stream<Uint8List> Function(int start, int end) read,
    required int size,
    required String name,
    required DateTime lastModified,
    List<TypedHeader> headers,
  }) = ContentResponse;

  /// Creates a response for serving a file from the file system.
  ///
  /// If the file does not exist when the response is created, a
  /// `404 Not Found` status response is returned.
  const factory Response.file(
    File file, {
    List<TypedHeader> headers,
  }) = FileResponse;

  static Stream<Uint8List> _deferSseStream(
    Stream<SseEvent> Function() streamBuilder,
    SseErrorHandler? onError,
  ) async* {
    if (onError == null) {
      yield* streamBuilder().transform(const SseEncoder());
      return;
    }

    const encoder = SseEncoder();
    try {
      await for (final event in streamBuilder()) {
        yield encoder.convert(event);
      }
    } catch (error, stackTrace) {
      final event = await onError(error, stackTrace);
      if (event != null) {
        yield encoder.convert(event);
      }
    }
  }

  /// The HTTP status code of this response.
  final HttpStatusCode status;

  /// The list of headers attached to this response.
  final List<TypedHeader> headers;

  /// The body payload of this response.
  final ResponseBody body;

  /// Optional upgrade callback for switching protocols (e.g. WebSocket).
  final FutureOr<void> Function(StreamChannel<List<int>> channel)? onUpgrade;

  /// The length of the content body in bytes, if known.
  int? get contentLength => body.contentLength;

  /// Returns a copy of this response with [extraHeaders] set, like
  /// `Header.Set` in Go: headers already present under the same names are
  /// removed first. Several entries with one name in [extraHeaders] are all
  /// kept.
  ///
  /// This replaces `Set-Cookie` too. To add a header next to the existing
  /// ones, such as another cookie, use [withAppendedHeaders].
  Response withHeaders(Iterable<TypedHeader> extraHeaders) {
    if (extraHeaders.isEmpty) return this;
    return copyWithHeaders(headers.replacing(extraHeaders));
  }

  /// Returns a copy of this response with [extraHeaders] added after the
  /// existing headers, like `Header.Add` in Go. Nothing is removed.
  Response withAppendedHeaders(Iterable<TypedHeader> extraHeaders) {
    if (extraHeaders.isEmpty) return this;
    return copyWithHeaders([...headers, ...extraHeaders]);
  }

  /// Returns a copy of this response with exactly [headers].
  ///
  /// [headers] are written as given, including repeated names. Subclasses
  /// override this to keep their type through [withHeaders] and
  /// [withAppendedHeaders].
  Response copyWithHeaders(List<TypedHeader> headers) {
    return Response(
      status: status,
      headers: headers,
      body: body,
      onUpgrade: onUpgrade,
    );
  }

  /// Returns a new [Response] with [newBody] replacing its current body.
  Response withBody(ResponseBody newBody) {
    return Response(
      status: status,
      headers: headers,
      body: newBody,
      onUpgrade: onUpgrade,
    );
  }
}

/// An abstract [Response] subclass that requires incoming [Request] context
/// to be resolved into a concrete [Response] (e.g. WebSocket handshakes, Range
/// requests, or file preconditions).
abstract class ResolvableResponse extends Response {
  const ResolvableResponse({
    super.status = .ok,
    super.headers = const [],
    super.body = const .empty(),
    super.onUpgrade,
  });

  /// Resolves this response for transmission given the incoming [request].
  FutureOr<Response> resolve(Request request);

  @override
  ResolvableResponse withHeaders(Iterable<TypedHeader> extraHeaders) {
    if (extraHeaders.isEmpty) return this;
    return copyWithHeaders(headers.replacing(extraHeaders));
  }

  @override
  ResolvableResponse withAppendedHeaders(Iterable<TypedHeader> extraHeaders) {
    if (extraHeaders.isEmpty) return this;
    return copyWithHeaders([...headers, ...extraHeaders]);
  }

  @override
  ResolvableResponse copyWithHeaders(List<TypedHeader> headers);
}

class WebSocketResponse extends ResolvableResponse {
  const WebSocketResponse(
    this.onWebSocket, {
    this.protocolSelector,
    this.compression = .none,
    this.maxMessageSize,
    this.checkOrigin,
    super.headers = const [],
  }) : super(status: .switchingProtocols);

  final FutureOr<void> Function(WebSocketChannel channel) onWebSocket;
  final String? Function(List<String> requestedProtocols)? protocolSelector;
  final WebSocketDeflateOptions compression;
  final int? maxMessageSize;
  final bool Function(String? origin)? checkOrigin;

  @override
  WebSocketResponse copyWithHeaders(List<TypedHeader> headers) {
    return WebSocketResponse(
      onWebSocket,
      protocolSelector: protocolSelector,
      compression: compression,
      headers: headers,
      maxMessageSize: maxMessageSize,
      checkOrigin: checkOrigin,
    );
  }

  @override
  Response resolve(Request request) {
    final key = request.headers.secWebSocketKey;
    final version = request.headers.secWebSocketVersion;
    if (!request.isWebSocketUpgrade || key == null || version?.version != 13) {
      return const .status(.badRequest, headers: [.secWebSocketVersionV13()]);
    }

    final originHeader = request.headers.origin;
    final isOriginAllowed = checkOrigin != null
        ? checkOrigin!(originHeader?.encode().firstOrNull)
        : _defaultCheckSameOrigin(request.headers);

    if (!isOriginAllowed) {
      return const .status(.forbidden);
    }

    final acceptKey = WebSocketChannel.signKey(key.value);

    String? selectedProtocol;
    if (protocolSelector != null) {
      selectedProtocol = protocolSelector!(
        request.headers.secWebSocketProtocol?.protocols ?? const [],
      );
    }

    SecWebSocketExtensionsHeader? extensionHeader;
    var negotiatedCompression = WebSocketDeflateOptions.none;

    final reqExtensions = request.headers.secWebSocketExtensions;
    if (compression.enabled &&
        reqExtensions != null &&
        reqExtensions.perMessageDeflate) {
      final clientNoContext =
          reqExtensions.clientNoContextTakeover ||
          compression.clientNoContextTakeover;
      final serverNoContext =
          reqExtensions.serverNoContextTakeover ||
          compression.serverNoContextTakeover;

      negotiatedCompression = WebSocketDeflateOptions(
        clientNoContextTakeover: clientNoContext,
        serverNoContextTakeover: serverNoContext,
      );
      extensionHeader = SecWebSocketExtensionsHeader(
        perMessageDeflate: true,
        clientNoContextTakeover: clientNoContext,
        serverNoContextTakeover: serverNoContext,
      );
    }

    final upgradeHeaders = <TypedHeader>[
      const .upgradeWebsocket(),
      const .connectionUpgrade(),
      .secWebSocketAccept(acceptKey),
      if (selectedProtocol != null) .secWebSocketProtocol([selectedProtocol]),
      ?extensionHeader,
    ].replacing(headers);

    return .upgrade(
      (channel) async {
        final wsChannel = StreamWebSocketChannel(
          channel,
          protocol: selectedProtocol,
          deflateOptions: negotiatedCompression,
          maxMessageSize: maxMessageSize,
        );
        try {
          await onWebSocket(wsChannel);
        } catch (_) {
          await wsChannel.sink.close();
        }
      },
      headers: upgradeHeaders,
    );
  }
}

class ContentResponse extends ResolvableResponse {
  ContentResponse({
    required this.read,
    required this.size,
    required this.name,
    required this.lastModified,
    super.headers = const [],
  }) : super(status: .ok);

  final Stream<Uint8List> Function(int start, int end) read;
  final int size;
  final String name;
  final DateTime lastModified;

  @override
  ContentResponse copyWithHeaders(List<TypedHeader> headers) {
    return ContentResponse(
      read: read,
      size: size,
      name: name,
      lastModified: lastModified,
      headers: headers,
    );
  }

  @override
  Future<Response> resolve(Request request) async {
    final responseHeaders = <TypedHeader>[...headers];

    responseHeaders.addIfAbsent(const .acceptRangesBytes());
    responseHeaders.addIfAbsent(.lastModified(lastModified));

    if (!responseHeaders.has<ContentTypeHeader>()) {
      var mime = lookupMimeType(name);
      if (mime == null && size > 0) {
        try {
          final magicLen = size.clamp(0, defaultMagicNumbersMaxLength);
          final bytes = await read(
            0,
            magicLen,
          ).expand((chunk) => chunk).take(magicLen).toList();
          if (bytes.isNotEmpty) {
            mime = lookupMimeType(name, headerBytes: bytes);
          }
        } catch (_) {}
      }
      responseHeaders.add(.contentType(mime ?? 'application/octet-stream'));
    }

    final etag = headers.get<ETagHeader>();

    final (statusOverride, validRange) = HttpPreconditions.checkPreconditions(
      method: request.method,
      ifMatch: request.headers.ifMatch,
      ifUnmodifiedSince: request.headers.ifUnmodifiedSince,
      ifNoneMatch: request.headers.ifNoneMatch,
      ifModifiedSince: request.headers.ifModifiedSince,
      ifRange: request.headers.ifRange,
      rangeHeader: request.headers.range,
      modTime: lastModified,
      currentEtag: etag,
    );

    if (statusOverride != null) {
      if (statusOverride == .preconditionFailed) {
        return const .status(.preconditionFailed);
      }

      if (statusOverride == .notModified) {
        return .status(
          .notModified,
          headers: responseHeaders
              .where(
                (h) =>
                    h is ETagHeader ||
                    h is LastModifiedHeader ||
                    h is CacheControlHeader ||
                    h is VaryHeader,
              )
              .toList(),
        );
      }

      return .status(statusOverride);
    }

    final isHead = request.method == .head;

    if (validRange != null) {
      try {
        final ranges = validRange.ranges(size);
        if (ranges.isNotEmpty) {
          final range = ranges.first;

          return .stream(
            isHead
                ? const Stream.empty()
                : read(range.start, range.start + range.length),
            status: .partialContent,
            contentLength: range.length,
            headers: responseHeaders.replacing([
              .contentRangeBytes(
                range.start,
                range.start + range.length - 1,
                size,
              ),
            ]),
          );
        }
      } on HttpRangeNoOverlapException {
        return .status(
          .rangeNotSatisfiable,
          headers: [.contentRangeUnsatisfiedBytes(size)],
        );
      } on HttpRangeInvalidException {
        // Fallback to full content on invalid range syntax
      }
    }

    return .stream(
      isHead ? const Stream.empty() : read(0, size),
      contentLength: size,
      headers: responseHeaders,
    );
  }
}

class FileResponse extends ResolvableResponse {
  const FileResponse(
    this.file, {
    super.headers = const [],
  }) : super(status: .ok);

  final File file;

  @override
  FileResponse copyWithHeaders(List<TypedHeader> headers) {
    return FileResponse(file, headers: headers);
  }

  @override
  Future<Response> resolve(Request request) async {
    if (!file.existsSync()) {
      return const .status(.notFound);
    }

    final stat = file.statSync();

    return ContentResponse(
      read: (start, end) => file.openRead(start, end).cast<Uint8List>(),
      size: stat.size,
      name: file.path,
      lastModified: stat.modified,
      headers: headers,
    ).resolve(request);
  }
}

extension IsWebSocketUpgrade on Request {
  bool get isWebSocketUpgrade {
    if (method != .get) return false;
    if (headers.connection?.isUpgrade != true) return false;
    final upgradeValue = headers.upgrade;
    if (upgradeValue == null) return false;
    return upgradeValue.protocols.any((p) => p.toLowerCase() == 'websocket');
  }
}

bool _defaultCheckSameOrigin(TypedHeaders headers) {
  final originHeader = headers.origin;
  if (originHeader == null || originHeader.isNull) return true;

  final hostHeader = headers.host;
  if (hostHeader == null || !hostHeader.isValid) return false;

  if (!originHeader.host.equalsIgnoreAsciiCase(hostHeader.host)) return false;

  if (hostHeader.port != null &&
      originHeader.port != null &&
      originHeader.port != hostHeader.port) {
    return false;
  }

  return true;
}

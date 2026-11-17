import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ion_web/src/http/http.dart';
import 'package:ion_web/src/response.dart';
import 'package:meta/meta.dart';

/// Serializes HTTP responses (headers and body) directly to network sockets.
typedef ResponseWriteResult = (
  int bytesWritten,
  bool keepAlive,
);

abstract final class HttpResponseWriter {
  /// Bodies up to this size are sent in the same buffer as the headers.
  static const int _maxInlineBodyBytes = 4096;

  /// Initial room for the response head. Typical heads fit; [ByteWriter]
  /// grows when they don't. Not estimated up front, because
  /// `TypedHeader.value` builds its string on every call.
  static const int _headBytes = 512;

  static final Uint8List _crlf = Uint8List.fromList([13, 10]);
  static final Uint8List _connectionKeepAlive = ascii.encode(
    'Connection: keep-alive\r\n',
  );
  static final Uint8List _connectionClose = ascii.encode(
    'Connection: close\r\n',
  );
  static final Uint8List _contentLengthPrefix = ascii.encode(
    'Content-Length: ',
  );
  static final Uint8List _transferEncodingChunked = ascii.encode(
    'Transfer-Encoding: chunked\r\n',
  );
  static final Uint8List _chunkedEnd = ascii.encode('0\r\n\r\n');

  static final Map<int, Uint8List> _statusLineCache = {};

  static final Map<int, String> _statusPhrases = {
    for (final status in HttpStatusCode.values)
      status.value: status.reasonPhrase,
  };

  static Uint8List _statusLine(int code) {
    return _statusLineCache[code] ??= ascii.encode(
      'HTTP/1.1 $code ${_statusPhrases[code] ?? 'Unknown'}\r\n',
    );
  }

  /// Writes status line, headers, and body to [socket] and returns
  /// [ResponseWriteResult] with bytes written and effective keepAlive flag.
  ///
  /// Message framing is owned by the writer: `Content-Length`,
  /// `Transfer-Encoding` and `Connection` entries in [headers] are not
  /// written as is. They are derived from [body], [status], [version] and
  /// [keepAlive] instead. A `Connection: close` in [headers] can turn
  /// keep-alive off, but nothing in [headers] can turn it on.
  ///
  /// Throws [ResponseBodyException] when [body] fails after the response
  /// head was written; the connection must then be closed without writing
  /// anything else.
  static FutureOr<ResponseWriteResult> write(
    Socket socket, {
    required HttpMethod method,
    required bool keepAlive,
    required int status,
    required List<TypedHeader> headers,
    required ResponseBody body,
    HttpVersion version = .http11,
  }) async {
    var effectiveKeepAlive = keepAlive;
    var hasDate = false;

    // RFC 9110 §6.4.1: these responses never carry content.
    final hasNoContent = status < 200 || status == 204 || status == 304;
    final contentLength = hasNoContent ? null : body.contentLength;
    // HTTP/1.0 has no chunked coding: the end of the body is the end of the
    // connection.
    final isCloseDelimited =
        !hasNoContent && contentLength == null && version == .http10;
    if (isCloseDelimited) effectiveKeepAlive = false;

    final sendsBody = !hasNoContent && method != .head;
    final inlineBody = switch (body) {
      BytesResponseBody(:final bytes)
          when sendsBody && bytes.length <= _maxInlineBodyBytes =>
        bytes,
      _ => null,
    };

    // A fresh buffer per response: the socket keeps a reference to the bytes
    // until they are actually written, so the buffer must never be reused.
    final buf = ByteWriter(
      Uint8List(_headBytes + (inlineBody?.length ?? 0)),
    );
    buf.addBytes(_statusLine(status));

    if (contentLength != null) {
      buf.addBytes(_contentLengthPrefix);
      buf.addInt(contentLength);
      buf.addBytes(_crlf);
    } else if (!hasNoContent && !isCloseDelimited) {
      buf.addBytes(_transferEncodingChunked);
    }

    for (var i = 0; i < headers.length; i++) {
      if (headers._isDuplicateAt(i)) continue;

      final header = headers[i];
      final key = header.name;

      switch (key.length) {
        case 10 when key.equalsIgnoreAsciiCase('connection'):
          if (_hasCloseToken(header.value)) effectiveKeepAlive = false;
          continue;
        case 14 when key.equalsIgnoreAsciiCase('content-length'):
          continue;
        case 17 when key.equalsIgnoreAsciiCase('transfer-encoding'):
          continue;
        case 4 when key.equalsIgnoreAsciiCase('date'):
          hasDate = true;
      }

      buf.addHeader(key, header.value);
    }

    buf.addBytes(effectiveKeepAlive ? _connectionKeepAlive : _connectionClose);

    if (!hasDate) {
      buf.addBytes(_HttpDateCache.dateHeaderBytes);
    }

    buf.addBytes(_crlf);

    if (!sendsBody) {
      final headBytesCount = buf.pos;
      socket.add(buf.view());
      return (headBytesCount, effectiveKeepAlive);
    }

    // A small body is packed with the headers into one socket write
    if (inlineBody != null) {
      if (inlineBody.isNotEmpty) {
        buf.addBytes(inlineBody);
      }
      final totalBytesWritten = buf.pos;
      socket.add(buf.view());
      return (totalBytesWritten, effectiveKeepAlive);
    }

    // For streaming or large body, write headers first, then body payload
    final headBytesCount = buf.pos;
    socket.add(buf.view());

    final bodyBytesWritten = await body.writeTo(
      socket,
      isChunked: contentLength == null && !isCloseDelimited,
    );
    return (headBytesCount + bodyBytesWritten, effectiveKeepAlive);
  }

  /// Called by a server when it starts accepting connections, so the cached
  /// `Date` header is kept fresh by a timer instead of on every response.
  @internal
  static void retainDateCache() => _HttpDateCache.retain();

  /// Called by a server once it stops; undoes [retainDateCache].
  @internal
  static void releaseDateCache() => _HttpDateCache.release();

  /// Whether a `Connection` header value lists the `close` option.
  static bool _hasCloseToken(String value) {
    for (final token in value.split(',')) {
      if (token.trim().equalsIgnoreAsciiCase('close')) return true;
    }
    return false;
  }

  /// Writes a 101 Switching Protocols response head to [sink].
  static int writeUpgradeHead(
    IOSink sink, {
    required List<TypedHeader> headers,
  }) {
    final buf = ByteWriter(Uint8List(_headBytes));
    buf.addBytes(_statusLine(101));

    for (var i = 0; i < headers.length; i++) {
      if (headers._isDuplicateAt(i)) continue;
      final header = headers[i];
      buf.addHeader(header.name, header.value);
    }

    buf.addBytes(_HttpDateCache.dateHeaderBytes);
    buf.addBytes(_crlf);

    final headBytesCount = buf.pos;
    sink.add(buf.view());

    return headBytesCount;
  }
}

extension _HttpHeaderWriterBuffer on ByteWriter {
  void addHeader(String name, String value) {
    final nameLen = name.length;
    final valueLen = value.length;
    ensure(nameLen + valueLen + 4);
    final buf = bytes;
    var p = pos;

    for (var i = 0; i < nameLen; i++) {
      final c = name.codeUnitAt(i);
      if (c > 0xFF || !isTchar(c)) {
        throw ArgumentError.value(
          name,
          'header',
          'Invalid character in response header name',
        );
      }
      buf[p++] = c;
    }

    buf[p++] = 0x3A; // ':'
    buf[p++] = 0x20; // ' '

    for (var i = 0; i < valueLen; i++) {
      final c = value.codeUnitAt(i);
      if (c == 0x00 ||
          c == 0x0A ||
          c == 0x0D ||
          c > 0xFF ||
          isInvalidHeaderValueChar(c)) {
        throw ArgumentError.value(
          value,
          'header',
          'Invalid character in response header value',
        );
      }
      buf[p++] = c;
    }

    buf[p++] = 0x0D; // '\r'
    buf[p++] = 0x0A; // '\n'

    pos = p;
  }
}

extension on List<TypedHeader> {
  bool _isDuplicateAt(int currentIndex) {
    final key = this[currentIndex].name;
    if (key.length == 10 && key.equalsIgnoreAsciiCase('set-cookie')) {
      return false;
    }
    for (var j = currentIndex + 1; j < length; j++) {
      final nextKey = this[j].name;
      if (nextKey.length == key.length && nextKey.equalsIgnoreAsciiCase(key)) {
        return true;
      }
    }
    return false;
  }
}

/// The `Date` header line.
///
/// While at least one server is running, a periodic timer keeps it fresh
/// and reading it is free. The timer stops with the last server, so it does
/// not keep the isolate alive. Without a running server the line is rebuilt
/// on read, at most once per second.
abstract final class _HttpDateCache {
  static int _users = 0;
  static Timer? _timer;
  static int _cachedSecond = -1;
  static Uint8List _cachedBytes = Uint8List(0);

  static void retain() {
    if (_users++ == 0) {
      _refresh(DateTime.now());
      _timer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _refresh(DateTime.now()),
      );
    }
  }

  static void release() {
    assert(_users > 0, 'release() without retain()');
    if (--_users == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  static Uint8List get dateHeaderBytes {
    if (_timer == null) _refresh(DateTime.now());
    return _cachedBytes;
  }

  static void _refresh(DateTime now) {
    final second = now.millisecondsSinceEpoch ~/ 1000;
    if (second != _cachedSecond) {
      _cachedSecond = second;
      _cachedBytes = ascii.encode('Date: ${HttpDate.format(now)}\r\n');
    }
  }
}

/// Thrown by [HttpResponseWriter.write] when the response body fails after
/// the response head has already been written.
///
/// Nothing more can be written on that connection: the client has started
/// reading a response, so it has to be aborted.
class ResponseBodyException implements Exception {
  const ResponseBodyException(this.error, this.stackTrace);

  /// The error raised by the body stream, or a [StateError] when the stream
  /// did not match its declared content length.
  final Object error;
  final StackTrace stackTrace;

  @override
  String toString() => 'ResponseBodyException: $error';
}

extension on ResponseBody {
  FutureOr<int> writeTo(Socket socket, {required bool isChunked}) {
    return switch (this) {
      EmptyResponseBody() => 0,
      BytesResponseBody(:final bytes) => _writeBytes(socket, bytes),
      StreamResponseBody(:final stream, :final contentLength) => _writeStream(
        socket,
        stream,
        contentLength: contentLength,
        isChunked: isChunked,
      ),
    };
  }

  static int _writeBytes(Socket socket, Uint8List bytes) {
    if (bytes.isNotEmpty) {
      socket.add(bytes);
    }
    return bytes.length;
  }

  static Future<int> _writeStream(
    Socket socket,
    Stream<Uint8List> stream, {
    required int? contentLength,
    required bool isChunked,
  }) async {
    final iterator = StreamIterator(stream);
    try {
      var bodyBytesWritten = 0;
      var payloadBytes = 0;
      while (true) {
        final moveNextFuture = iterator.moveNext();

        var isPending = true;
        unawaited(
          moveNextFuture.then((_) => isPending = false, onError: (_) {}),
        );
        if (isPending) {
          await socket.flush();
        }

        final bool hasNext;
        try {
          hasNext = await moveNextFuture;
        } catch (error, stackTrace) {
          throw ResponseBodyException(error, stackTrace);
        }
        if (!hasNext) break;

        final chunk = iterator.current;
        if (chunk.isEmpty) continue;

        payloadBytes += chunk.length;
        if (contentLength != null && payloadBytes > contentLength) {
          throw ResponseBodyException(
            StateError(
              'Response body stream exceeds its content length of '
              '$contentLength bytes',
            ),
            StackTrace.current,
          );
        }

        if (isChunked) {
          final hexScratch = Uint8List(20);
          final hexLen = formatChunkHeader(hexScratch, chunk.length);
          socket.add(Uint8List.sublistView(hexScratch, 0, hexLen));

          socket.add(chunk);
          socket.add(HttpResponseWriter._crlf);
          bodyBytesWritten +=
              hexLen + chunk.length + HttpResponseWriter._crlf.length;
        } else {
          socket.add(chunk);
          bodyBytesWritten += chunk.length;
        }
      }

      if (contentLength != null && payloadBytes < contentLength) {
        throw ResponseBodyException(
          StateError(
            'Response body stream ended after $payloadBytes of '
            '$contentLength bytes',
          ),
          StackTrace.current,
        );
      }

      if (isChunked) {
        socket.add(HttpResponseWriter._chunkedEnd);
        bodyBytesWritten += HttpResponseWriter._chunkedEnd.length;
      }

      return bodyBytesWritten;
    } finally {
      await iterator.cancel();
    }
  }
}

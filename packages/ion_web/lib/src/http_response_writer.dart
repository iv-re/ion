import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ion_web/src/http/http.dart';
import 'package:ion_web/src/response.dart';

/// Serializes HTTP responses (headers and body) directly to network sockets.
typedef ResponseWriteResult = (
  int bytesWritten,
  bool keepAlive,
);

abstract final class HttpResponseWriter {
  static final ByteWriterPool _pool = ByteWriterPool();

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
  static FutureOr<ResponseWriteResult> write(
    Socket socket, {
    required HttpMethod method,
    required bool keepAlive,
    required int status,
    required List<TypedHeader> headers,
    required ResponseBody body,
  }) async {
    var hasKeepAlive = false;
    var effectiveKeepAlive = keepAlive;
    var hasDate = false;
    var hasTransferEncoding = false;

    final buf = _pool.acquire();
    try {
      buf.addBytes(_statusLine(status));

      final contentLength = body.contentLength;
      if (contentLength != null) {
        buf.addBytes(_contentLengthPrefix);
        buf.addInt(contentLength);
        buf.addBytes(_crlf);
      }

      for (var i = 0; i < headers.length; i++) {
        if (headers._isDuplicateAt(i)) continue;

        final header = headers[i];
        final key = header.name;
        final value = header.value;

        switch (key.length) {
          case 10 when key.equalsIgnoreAsciiCase('connection'):
            hasKeepAlive = true;
            effectiveKeepAlive = value == 'keep-alive';
          case 4 when key.equalsIgnoreAsciiCase('date'):
            hasDate = true;
          case 17 when key.equalsIgnoreAsciiCase('transfer-encoding'):
            hasTransferEncoding = true;
        }

        buf.addHeader(key, value);
      }

      if (contentLength == null && !hasTransferEncoding) {
        buf.addBytes(_transferEncodingChunked);
      }

      if (!hasKeepAlive) {
        buf.addBytes(
          effectiveKeepAlive ? _connectionKeepAlive : _connectionClose,
        );
      }

      if (!hasDate) {
        buf.addBytes(_HttpDateCache.dateHeaderBytes);
      }

      buf.addBytes(_crlf);

      // For HEAD requests, write headers only and return
      if (method == .head) {
        final headBytesCount = buf.pos;
        socket.add(buf.view());
        return (headBytesCount, effectiveKeepAlive);
      }

      // If body fits in buffer capacity, pack headers and body in one socket
      // write
      if (body case BytesResponseBody(:final bytes)) {
        if (buf.pos + bytes.length <= buf.bytes.length) {
          if (bytes.isNotEmpty) {
            buf.addBytes(bytes);
          }
          final totalBytesWritten = buf.pos;
          socket.add(buf.view());
          return (totalBytesWritten, effectiveKeepAlive);
        }
      }

      // For streaming or large body, write headers first, then body payload
      final headBytesCount = buf.pos;
      socket.add(buf.view());

      final bodyBytesWritten = await body.writeTo(socket);
      return (headBytesCount + bodyBytesWritten, effectiveKeepAlive);
    } finally {
      _pool.release(buf);
    }
  }

  /// Writes a 101 Switching Protocols response head to [sink].
  static int writeUpgradeHead(
    IOSink sink, {
    required List<TypedHeader> headers,
  }) {
    final buf = _pool.acquire();
    try {
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
    } finally {
      _pool.release(buf);
    }
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

abstract final class _HttpDateCache {
  static Timer? _timer;
  static Uint8List _cachedBytes = _format();

  static Uint8List get dateHeaderBytes {
    if (_timer == null) {
      _cachedBytes = _format();
      _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        _cachedBytes = _format();
      });
    }
    return _cachedBytes;
  }

  static Uint8List _format() {
    return ascii.encode('Date: ${HttpDate.format(DateTime.now())}\r\n');
  }
}

extension on ResponseBody {
  FutureOr<int> writeTo(Socket socket) {
    return switch (this) {
      EmptyResponseBody() => 0,
      BytesResponseBody(:final bytes) => _writeBytes(socket, bytes),
      StreamResponseBody(:final stream, :final contentLength) => _writeStream(
        socket,
        stream,
        contentLength: contentLength,
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
  }) async {
    final iterator = StreamIterator(stream);
    try {
      var bodyBytesWritten = 0;
      final isChunked = contentLength == null;
      while (true) {
        final moveNextFuture = iterator.moveNext();

        var isPending = true;
        unawaited(
          moveNextFuture.then((_) => isPending = false, onError: (_) {}),
        );
        if (isPending) {
          await socket.flush();
        }

        final hasNext = await moveNextFuture;
        if (!hasNext) break;

        final chunk = iterator.current;
        if (chunk.isEmpty) continue;

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

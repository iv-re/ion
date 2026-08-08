import 'dart:async';
import 'dart:typed_data';

import 'package:ion_web/src/http/http.dart';

final Uint8List _emptyBytes = Uint8List(0);

/// The maximum value of `_chunkSize` before shifting by 4 bits
/// (multiplying by 16)
/// to prevent overflow in a 64-bit signed integer.
///
/// This corresponds to `0x7FFFFFFFFFFFFFFF >> 4`.
// ignore: avoid_js_rounded_ints
const _maxChunkSizeBeforeShift = 0x07FFFFFFFFFFFFFF;

class BodyControllerException implements Exception {
  const BodyControllerException(this.message);

  final String message;
}

const int _maxUnreadBufferBytes = 256 * 1024;

/// A common interface for body controllers.
abstract interface class BodyController {
  Stream<Uint8List> get stream;
  bool get isDone;
  bool get hasListener;
  Uint8List add(Uint8List data);
  void close();
  void addError(Object error);
  Uint8List takeBufferedData();
}

/// Base class for body controllers providing stream buffering and lifecycle.
abstract base class _BaseBodyController implements BodyController {
  _BaseBodyController({
    required this._onDone,
    void Function()? onPause,
    void Function()? onResume,
    void Function()? onListen,
  }) {
    _controller = StreamController<Uint8List>(
      sync: true,
      onListen: () {
        _hasListener = true;
        onListen?.call();
        for (final chunk in _bufferedChunks) {
          if (!_controller.isClosed) {
            _controller.add(chunk);
          }
        }
        _bufferedChunks.clear();
        _bufferedLength = 0;
        if (_isClosed && !_controller.isClosed) {
          _controller.close();
        }
      },
      onPause: onPause,
      onResume: onResume,
    );
  }

  late final StreamController<Uint8List> _controller;
  final void Function() _onDone;

  final _bufferedChunks = <Uint8List>[];
  int _bufferedLength = 0;
  bool _hasListener = false;
  bool _isClosed = false;

  @override
  Stream<Uint8List> get stream => _controller.stream;

  @override
  bool get hasListener => _hasListener;

  @override
  Uint8List takeBufferedData() {
    if (_bufferedChunks.isEmpty) return _emptyBytes;
    final result = Uint8List(_bufferedLength);
    var offset = 0;
    for (final chunk in _bufferedChunks) {
      result.setAll(offset, chunk);
      offset += chunk.length;
    }
    _bufferedChunks.clear();
    _bufferedLength = 0;
    return result;
  }

  void _addChunk(Uint8List chunk) {
    if (_hasListener) {
      if (!_controller.isClosed) {
        _controller.add(chunk);
      }
    } else {
      if (_bufferedLength + chunk.length <= _maxUnreadBufferBytes) {
        _bufferedChunks.add(chunk);
        _bufferedLength += chunk.length;
      }
    }
  }

  void _close() {
    if (!_isClosed) {
      _isClosed = true;
      if (_hasListener && !_controller.isClosed) {
        _controller.close();
      }
      _onDone();
    }
  }

  @override
  void addError(Object error) {
    if (!_controller.isClosed) {
      _controller.addError(error);
    }
  }
}

/// A stream controller for a fixed-length HTTP request body.
final class FixedLengthBodyController extends _BaseBodyController {
  FixedLengthBodyController(
    this._contentLength, {
    required super.onDone,
    super.onPause,
    super.onResume,
    super.onListen,
  });

  final int _contentLength;
  int _consumed = 0;

  @override
  bool get isDone => _consumed >= _contentLength;

  /// Adds [data] to the body stream.
  ///
  /// Returns any remaining data that was not part of the body (pipelining).
  @override
  Uint8List add(Uint8List data) {
    if (data.isEmpty) return _emptyBytes;

    final remainingInBody = _contentLength - _consumed;
    if (data.length <= remainingInBody) {
      _addChunk(data);
      _consumed += data.length;
      if (_consumed == _contentLength) {
        _close();
      }
      return _emptyBytes;
    } else {
      _addChunk(Uint8List.sublistView(data, 0, remainingInBody));
      _consumed = _contentLength;
      _close();
      return Uint8List.sublistView(data, remainingInBody);
    }
  }

  /// Closes the stream and stops sending data to listeners.
  /// The controller will still track consumption for draining purposes.
  @override
  void close() {
    if (!_controller.isClosed) {
      _controller.close();
      // We don't call _onDone here because we still need to wait for
      // the actual bytes to be 'add'ed from the socket.
    }
  }
}

enum _ChunkState {
  size,
  sizeCR,
  extNameStart,
  extName,
  extNameAfterBws,
  extValStart,
  extValToken,
  extValAfterBws,
  extValQuoted,
  extValQuotedEscape,
  extValAfterQuoted,
  data,
  dataCR,
  dataCRLF,
  trailers,
  trailersCR,
}

/// A stream controller for a chunked HTTP request body.
final class ChunkedBodyController extends _BaseBodyController {
  ChunkedBodyController({
    required super.onDone,
    super.onPause,
    super.onResume,
    super.onListen,
  });

  static const _maxLineBytes = 4096;
  static const _maxTrailerBytes = 16384;

  _ChunkState _state = .size;
  int _chunkSize = 0;
  int _chunkBytesRead = 0;
  int _trailerState = 0;
  int _lineBytesRead = 0;
  int _totalTrailerBytes = 0;
  bool _hasHexDigit = false;

  bool _isDone = false;

  @override
  bool get isDone => _isDone;

  @override
  Uint8List add(Uint8List data) {
    if (_isDone || data.isEmpty) return data;

    var pos = 0;
    while (pos < data.length) {
      if (_isDone) {
        return Uint8List.sublistView(data, pos);
      }

      switch (_state) {
        case .size:
          final byte = data[pos];
          if (_lineBytesRead >= _maxLineBytes) {
            throw const BodyControllerException(
              'Chunk header line too long',
            );
          }
          _lineBytesRead++;
          if (byte.isCr) {
            if (!_hasHexDigit) {
              throw const BodyControllerException('Invalid chunk size');
            }
            _state = .sizeCR;
            pos++;
          } else if (byte.isLf) {
            if (!_hasHexDigit) {
              throw const BodyControllerException('Invalid chunk size');
            }
            pos++;
            _lineBytesRead = 0;
            _hasHexDigit = false;
            if (_chunkSize == 0) {
              _state = .trailers;
            } else {
              _chunkBytesRead = 0;
              _state = .data;
            }
          } else if (byte.isSemicolon) {
            if (!_hasHexDigit) {
              throw const BodyControllerException('Invalid chunk size');
            }
            _state = .extNameStart;
            pos++;
          } else {
            final hex = parseHex(byte);
            if (hex < 0) {
              throw const BodyControllerException('Invalid chunk size');
            }
            if (_chunkSize > _maxChunkSizeBeforeShift) {
              throw const BodyControllerException('Chunk size too large');
            }
            _chunkSize = (_chunkSize << 4) + hex;
            _hasHexDigit = true;
            pos++;
          }
        case .sizeCR:
          final byte = data[pos];
          if (!byte.isLf) {
            throw const BodyControllerException(
              'Bare CR in chunk header line',
            );
          }
          pos++;
          _lineBytesRead = 0;
          _hasHexDigit = false;
          if (_chunkSize == 0) {
            _state = .trailers;
          } else {
            _chunkBytesRead = 0;
            _state = .data;
          }
        case .extNameStart:
          final byte = data[pos];
          if (_lineBytesRead >= _maxLineBytes) {
            throw const BodyControllerException(
              'Chunk extension line too long',
            );
          }
          _lineBytesRead++;
          if (byte == 32 || byte == 9) {
            pos++;
          } else if (isTchar(byte)) {
            _state = .extName;
            pos++;
          } else {
            throw const BodyControllerException(
              'Invalid or missing chunk extension name',
            );
          }
        case .extName:
          final byte = data[pos];
          if (_lineBytesRead >= _maxLineBytes) {
            throw const BodyControllerException(
              'Chunk extension line too long',
            );
          }
          _lineBytesRead++;
          if (isTchar(byte)) {
            pos++;
          } else if (byte == 32 || byte == 9) {
            _state = .extNameAfterBws;
            pos++;
          } else if (byte == 61) {
            _state = .extValStart;
            pos++;
          } else if (byte.isSemicolon) {
            _state = .extNameStart;
            pos++;
          } else if (byte.isCr) {
            _state = .sizeCR;
            pos++;
          } else if (byte.isLf) {
            pos++;
            _lineBytesRead = 0;
            _hasHexDigit = false;
            if (_chunkSize == 0) {
              _state = .trailers;
            } else {
              _chunkBytesRead = 0;
              _state = .data;
            }
          } else {
            throw const BodyControllerException(
              'Invalid character in chunk extension name',
            );
          }
        case .extNameAfterBws:
          final byte = data[pos];
          if (_lineBytesRead >= _maxLineBytes) {
            throw const BodyControllerException(
              'Chunk extension line too long',
            );
          }
          _lineBytesRead++;
          if (byte == 32 || byte == 9) {
            pos++;
          } else if (byte == 61) {
            _state = .extValStart;
            pos++;
          } else if (byte.isSemicolon) {
            _state = .extNameStart;
            pos++;
          } else if (byte.isCr) {
            _state = .sizeCR;
            pos++;
          } else if (byte.isLf) {
            pos++;
            _lineBytesRead = 0;
            _hasHexDigit = false;
            if (_chunkSize == 0) {
              _state = .trailers;
            } else {
              _chunkBytesRead = 0;
              _state = .data;
            }
          } else {
            throw const BodyControllerException(
              'Unexpected character after chunk extension name',
            );
          }
        case .extValStart:
          final byte = data[pos];
          if (_lineBytesRead >= _maxLineBytes) {
            throw const BodyControllerException(
              'Chunk extension line too long',
            );
          }
          _lineBytesRead++;
          if (byte == 32 || byte == 9) {
            pos++;
          } else if (byte == 34) {
            _state = .extValQuoted;
            pos++;
          } else if (isTchar(byte)) {
            _state = .extValToken;
            pos++;
          } else {
            throw const BodyControllerException(
              'Invalid or missing chunk extension value',
            );
          }
        case .extValToken:
          final byte = data[pos];
          if (_lineBytesRead >= _maxLineBytes) {
            throw const BodyControllerException(
              'Chunk extension line too long',
            );
          }
          _lineBytesRead++;
          if (isTchar(byte)) {
            pos++;
          } else if (byte == 32 || byte == 9) {
            _state = .extValAfterBws;
            pos++;
          } else if (byte.isSemicolon) {
            _state = .extNameStart;
            pos++;
          } else if (byte.isCr) {
            _state = .sizeCR;
            pos++;
          } else if (byte.isLf) {
            pos++;
            _lineBytesRead = 0;
            _hasHexDigit = false;
            if (_chunkSize == 0) {
              _state = .trailers;
            } else {
              _chunkBytesRead = 0;
              _state = .data;
            }
          } else {
            throw const BodyControllerException(
              'Invalid character in chunk extension value',
            );
          }
        case .extValAfterBws:
          final byte = data[pos];
          if (_lineBytesRead >= _maxLineBytes) {
            throw const BodyControllerException(
              'Chunk extension line too long',
            );
          }
          _lineBytesRead++;
          if (byte == 32 || byte == 9) {
            pos++;
          } else if (byte.isSemicolon) {
            _state = .extNameStart;
            pos++;
          } else if (byte.isCr) {
            _state = .sizeCR;
            pos++;
          } else if (byte.isLf) {
            pos++;
            _lineBytesRead = 0;
            _hasHexDigit = false;
            if (_chunkSize == 0) {
              _state = .trailers;
            } else {
              _chunkBytesRead = 0;
              _state = .data;
            }
          } else {
            throw const BodyControllerException(
              'Unexpected character after chunk extension value',
            );
          }
        case .extValQuoted:
          final byte = data[pos];
          if (_lineBytesRead >= _maxLineBytes) {
            throw const BodyControllerException(
              'Chunk extension line too long',
            );
          }
          _lineBytesRead++;
          if (byte == 34) {
            _state = .extValAfterQuoted;
            pos++;
          } else if (byte == 92) {
            _state = .extValQuotedEscape;
            pos++;
          } else if (byte == 9 ||
              (byte >= 32 && byte != 34 && byte != 92 && byte != 127) ||
              byte >= 128) {
            pos++;
          } else {
            throw const BodyControllerException(
              'Invalid character in quoted chunk extension value',
            );
          }
        case .extValQuotedEscape:
          final byte = data[pos];
          if (_lineBytesRead >= _maxLineBytes) {
            throw const BodyControllerException(
              'Chunk extension line too long',
            );
          }
          _lineBytesRead++;
          if (byte == 9 || (byte >= 32 && byte <= 126) || byte >= 128) {
            _state = .extValQuoted;
            pos++;
          } else {
            throw const BodyControllerException(
              'Invalid escape sequence in quoted chunk extension value',
            );
          }
        case .extValAfterQuoted:
          final byte = data[pos];
          if (_lineBytesRead >= _maxLineBytes) {
            throw const BodyControllerException(
              'Chunk extension line too long',
            );
          }
          _lineBytesRead++;
          if (byte == 32 || byte == 9) {
            pos++;
          } else if (byte.isSemicolon) {
            _state = .extNameStart;
            pos++;
          } else if (byte.isCr) {
            _state = .sizeCR;
            pos++;
          } else if (byte.isLf) {
            pos++;
            _lineBytesRead = 0;
            _hasHexDigit = false;
            if (_chunkSize == 0) {
              _state = .trailers;
            } else {
              _chunkBytesRead = 0;
              _state = .data;
            }
          } else {
            throw const BodyControllerException(
              'Unexpected character after quoted chunk extension value',
            );
          }
        case .data:
          final remainingInChunk = _chunkSize - _chunkBytesRead;
          final remainingInData = data.length - pos;
          final take = remainingInChunk < remainingInData
              ? remainingInChunk
              : remainingInData;

          _addChunk(Uint8List.sublistView(data, pos, pos + take));

          _chunkBytesRead += take;
          pos += take;

          if (_chunkBytesRead == _chunkSize) {
            _state = .dataCR;
          }
        case .dataCR:
          final byte = data[pos];
          if (!byte.isCr) {
            throw const BodyControllerException(
              'CRLF expected after chunk data',
            );
          }
          pos++;
          _state = .dataCRLF;
        case .dataCRLF:
          final byte = data[pos];
          if (!byte.isLf) {
            throw const BodyControllerException(
              'CRLF expected after chunk data',
            );
          }
          pos++;
          _lineBytesRead = 0;
          _chunkSize = 0;
          _hasHexDigit = false;
          _state = .size;
        case .trailers:
          final byte = data[pos];
          if (_lineBytesRead >= _maxLineBytes) {
            throw const BodyControllerException('Trailer line too long');
          }
          if (_totalTrailerBytes >= _maxTrailerBytes) {
            throw const BodyControllerException(
              'Chunk trailers exceed max size limit',
            );
          }
          _lineBytesRead++;
          _totalTrailerBytes++;
          if (byte.isCr) {
            pos++;
            _state = .trailersCR;
          } else if (byte.isLf) {
            pos++;
            _lineBytesRead = 0;
            if (_trailerState == 0) {
              _isDone = true;
              _close();
              return Uint8List.sublistView(data, pos);
            } else {
              _trailerState = 0;
            }
          } else {
            pos++;
            _trailerState = 1;
          }
        case .trailersCR:
          final byte = data[pos];
          if (!byte.isLf) {
            throw const BodyControllerException(
              'Bare CR in chunk trailers',
            );
          }
          pos++;
          _lineBytesRead = 0;
          if (_trailerState == 0) {
            _isDone = true;
            _close();
            return Uint8List.sublistView(data, pos);
          } else {
            _trailerState = 0;
            _state = .trailers;
          }
      }
    }

    return _emptyBytes;
  }

  @override
  void close() {
    if (!_isDone && !_controller.isClosed) {
      _controller.addError(
        const BodyControllerException('Incomplete chunked body'),
      );
    }
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}

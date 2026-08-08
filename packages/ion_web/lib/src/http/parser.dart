import 'dart:typed_data';

import 'package:ion_web/src/http/http.dart';

class HttpParserException implements Exception {
  const HttpParserException(this.message);

  final String message;
}

typedef HttpRequestHead = ({
  HttpMethod method,
  Uri uri,
  HttpVersion version,
  List<HeaderEntrySlices> headerSlices,
  int consumedBytesInLastChunk,
});

enum _ParserState {
  method,
  url,
  version,
  headerKey,
  headerValue,
  endOfHeaders,
}

class HttpParser {
  HttpParser({
    int maxHeaderSize = 64 * 1024,
    this.maxHeaderCount = 500,
  }) : _buffer = Uint8List(maxHeaderSize);

  final Uint8List _buffer;
  final int maxHeaderCount;
  int _bufferPos = 0;

  _ParserState _state = .method;

  HttpMethod? _method;
  String? _url;
  HttpVersion? _version;
  final List<HeaderEntrySlices> _headerSlices = [];

  int _currentFieldStart = 0;
  HeaderByteSlice? _currentHeaderKeySlice;
  SliceBufferToken _token = SliceBufferToken();

  int _consumedBytesInLastChunk = 0;

  HttpRequestHead? feed(Uint8List chunk) {
    _consumedBytesInLastChunk = 0;

    for (var i = 0; i < chunk.length; i++) {
      _consumedBytesInLastChunk++;
      final byte = chunk[i];

      if (_bufferPos >= _buffer.length) {
        throw const HttpParserException(
          'Request header section exceeds size limit',
        );
      }

      _buffer[_bufferPos++] = byte;

      switch (_state) {
        case .method:
          if (byte.isSpace) {
            _method = _parseMethod(_buffer, _bufferPos - 1);
            _currentFieldStart = _bufferPos;
            _state = .url;
          } else {
            if (byte == 0 || byte.isLf || byte.isCr) {
              throw const HttpParserException('Invalid character in method');
            }
          }
        case .url:
          if (byte.isSpace) {
            _url = String.fromCharCodes(
              _buffer,
              _currentFieldStart,
              _bufferPos - 1,
            );
            if (_url == '*' && _method != HttpMethod.options) {
              throw const HttpParserException(
                'Asterisk-form URI is only allowed for OPTIONS method',
              );
            }
            _currentFieldStart = _bufferPos;
            _state = .version;
          } else {
            if (isInvalidUrlChar(byte)) {
              throw const HttpParserException('Invalid character in URL');
            }
          }
        case .version:
          if (byte.isLf) {
            _expectCrBeforeLf();

            final len = _bufferPos - 2 - _currentFieldStart;
            _version = _parseVersion(_buffer, _currentFieldStart, len);
            _currentFieldStart = _bufferPos;
            _state = .headerKey;
          }
        case .headerKey:
          if (byte.isColon) {
            final start = _currentFieldStart;
            final end = _bufferPos - 1;

            if (start == end) {
              throw const HttpParserException('Empty header field-name');
            }

            _currentHeaderKeySlice = HeaderByteSlice(
              _buffer,
              start,
              end,
              _token,
            );
            _currentFieldStart = _bufferPos;
            _state = .headerValue;
          } else if (byte.isLf) {
            _expectCrBeforeLf();

            if (_bufferPos - 2 != _currentFieldStart) {
              throw const HttpParserException(
                'Invalid header field: missing colon delimiter',
              );
            }

            _state = .endOfHeaders;

            final Uri uri;
            try {
              uri = .parse(_url!);
            } on FormatException {
              throw const HttpParserException('Invalid URI');
            }

            return (
              method: _method!,
              uri: uri,
              version: _version!,
              headerSlices: List.of(_headerSlices, growable: false),
              consumedBytesInLastChunk: _consumedBytesInLastChunk,
            );
          } else if (byte.isCr) {
            if (_bufferPos - 1 != _currentFieldStart) {
              throw const HttpParserException(
                'Invalid character in header key',
              );
            }
          } else if (!isTchar(byte)) {
            throw const HttpParserException('Invalid character in header key');
          }
        case .headerValue:
          if (byte.isLf) {
            _expectCrBeforeLf();

            var start = _currentFieldStart;
            final end = _bufferPos - 2;

            while (start < end && _buffer[start].isSpace) {
              start++;
            }

            for (var i = start; i < end; i++) {
              if (_buffer[i].isCr) {
                throw const HttpParserException('Bare CR in header value');
              }
            }

            final valSlice = HeaderByteSlice(_buffer, start, end, _token);
            if (_headerSlices.length >= maxHeaderCount) {
              throw const HttpParserException(
                'Request header count exceeds limit',
              );
            }
            _headerSlices.add(
              HeaderEntrySlices(_currentHeaderKeySlice!, valSlice),
            );

            _currentHeaderKeySlice = null;

            _currentFieldStart = _bufferPos;
            _state = .headerKey;
          } else if (isInvalidHeaderValueChar(byte)) {
            throw const HttpParserException(
              'Invalid character in header value',
            );
          }
        case .endOfHeaders:
          break;
      }
    }

    return null;
  }

  void reset() {
    _state = .method;
    _bufferPos = 0;
    _currentFieldStart = 0;
    _consumedBytesInLastChunk = 0;
    _method = null;
    _url = null;
    _version = null;
    _currentHeaderKeySlice = null;
    _headerSlices.clear();
    _token.invalidate();
    _token = SliceBufferToken();
  }

  void _expectCrBeforeLf() {
    if (!_buffer[_bufferPos - 2].isCr) {
      throw const HttpParserException('Invalid line ending: expected CRLF');
    }
  }

  HttpMethod _parseMethod(Uint8List b, int len) {
    if (len == 3) {
      if (b[0] == 71 && b[1] == 69 && b[2] == 84) return .get;
      if (b[0] == 80 && b[1] == 85 && b[2] == 84) return .put;
    }

    if (len == 4) {
      if (b[0] == 80 && b[1] == 79 && b[2] == 83 && b[3] == 84) return .post;
      if (b[0] == 72 && b[1] == 69 && b[2] == 65 && b[3] == 68) return .head;
    }

    if (len == 5) {
      if (b[0] == 80 && b[1] == 65 && b[2] == 84 && b[3] == 67 && b[4] == 72) {
        return .patch;
      }
      if (b[0] == 84 && b[1] == 82 && b[2] == 65 && b[3] == 67 && b[4] == 69) {
        return .trace;
      }
    }

    if (len == 6) {
      if (b[0] == 68 &&
          b[1] == 69 &&
          b[2] == 76 &&
          b[3] == 69 &&
          b[4] == 84 &&
          b[5] == 69) {
        return .delete;
      }
    }

    if (len == 7) {
      if (b[0] == 79 &&
          b[1] == 80 &&
          b[2] == 84 &&
          b[3] == 73 &&
          b[4] == 79 &&
          b[5] == 78 &&
          b[6] == 83) {
        return .options;
      }
      if (b[0] == 67 &&
          b[1] == 79 &&
          b[2] == 78 &&
          b[3] == 78 &&
          b[4] == 69 &&
          b[5] == 67 &&
          b[6] == 84) {
        return .connect;
      }
    }

    return HttpMethod(String.fromCharCodes(b, 0, len));
  }

  HttpVersion _parseVersion(Uint8List b, int start, int len) {
    if (len == 8) {
      if (b[start + 0] == 72 /* 'H' */ &&
          b[start + 1] == 84 /* 'T' */ &&
          b[start + 2] == 84 /* 'T' */ &&
          b[start + 3] == 80 /* 'P' */ &&
          b[start + 4] == 47 /* '/' */ &&
          b[start + 5] == 49 /* '1' */ &&
          b[start + 6] == 46 /* '.' */ ) {
        final lastChar = b[start + 7];
        if (lastChar == 49 /* '1' */ ) return .http11;
        if (lastChar == 48 /* '0' */ ) return .http10;
      }
    }

    if (len != 8) {
      throw const HttpParserException('Invalid HTTP version length');
    }

    if (b[start + 0] != 72 ||
        b[start + 1] != 84 ||
        b[start + 2] != 84 ||
        b[start + 3] != 80 ||
        b[start + 4] != 47) {
      throw const HttpParserException('Invalid HTTP version prefix');
    }

    if (b[start + 6] != 46) {
      throw const HttpParserException('Invalid HTTP version separator');
    }

    final majChar = b[start + 5];
    final minChar = b[start + 7];

    if (majChar < 48 || majChar > 57 || minChar < 48 || minChar > 57) {
      throw const HttpParserException('Invalid HTTP version digits');
    }

    return HttpVersion((majChar - 48, minChar - 48));
  }
}

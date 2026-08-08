import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ion_web/src/http/utils.dart';

/// Exception thrown when multipart parsing fails.
class MultipartException implements Exception {
  const MultipartException(this.message);

  final String message;

  @override
  String toString() => 'MultipartException: $message';
}

/// Exception thrown when a request is not a multipart request.
class NotMultipartException extends MultipartException {
  const NotMultipartException()
    : super("request Content-Type isn't multipart/form-data");
}

/// Exception thrown when the multipart request lacks a boundary parameter
/// in Content-Type.
class MissingBoundaryException extends MultipartException {
  const MissingBoundaryException()
    : super('no multipart boundary param in Content-Type');
}

/// Represents a single part of a multipart request body.
///
/// It extends [StreamView] of [Uint8List] to allow streaming the part's bytes.
class MultipartPart extends StreamView<Uint8List> {
  const MultipartPart({
    required this.name,
    required this.filename,
    required this.contentType,
    required this.headers,
    required Stream<Uint8List> bytes,
  }) : super(bytes);

  /// The field name associated with this part.
  final String? name;

  /// The filename if this part represents an uploaded file.
  final String? filename;

  /// The Content-Type header value of this part, if provided.
  final String? contentType;

  /// The headers of this part.
  final Map<String, String> headers;

  /// Reads the entire part's bytes into a single [Uint8List].
  Future<Uint8List> bytes() async {
    final builder = BytesBuilder(copy: false);
    await forEach(builder.add);
    return builder.takeBytes();
  }

  /// Decodes the entire part's bytes into a [String] using the given [decoder]
  /// (defaults to UTF-8).
  Future<String> text({Converter<List<int>, String>? decoder}) async {
    final allBytes = await bytes();
    return (decoder ?? utf8.decoder).convert(allBytes);
  }
}

/// An RFC 7578 and RFC 2046 compliant streaming parser for
/// `multipart/form-data` and `multipart/mixed` MIME streams.
///
/// Unlike `MimeMultipartTransformer` from `package:mime`, this parser
/// guarantees that if the underlying socket stream terminates prematurely or
/// emits an error, any active part stream receives an exception and closes
/// immediately, preventing hangs.
class MultipartStreamTransformer
    extends StreamTransformerBase<List<int>, MultipartPart> {
  MultipartStreamTransformer(
    this.boundary, {
    this.maxHeaderSize = 64 * 1024,
  }) {
    if (boundary.isEmpty) {
      throw ArgumentError('Multipart boundary cannot be empty');
    }
  }

  final String boundary;
  final int maxHeaderSize;

  @override
  Stream<MultipartPart> bind(Stream<List<int>> stream) {
    final controller = StreamController<MultipartPart>(sync: true);
    final parser = _MultipartParser(
      boundary,
      controller,
      maxHeaderSize: maxHeaderSize,
    );

    StreamSubscription<List<int>>? subscription;

    controller.onListen = () {
      subscription = stream.listen(
        parser.onData,
        onError: parser.onError,
        onDone: parser.onDone,
        cancelOnError: true,
      );
    };

    controller.onPause = () {};
    controller.onResume = () => subscription?.resume();
    controller.onCancel = () {
      subscription?.cancel();
      parser.dispose();
    };

    return controller.stream;
  }
}

enum _ParserState {
  start,
  headers,
  body,
  boundaryTail,
  end,
}

class _MultipartParser {
  _MultipartParser(
    String boundary,
    this._mainController, {
    this.maxHeaderSize = 64 * 1024,
  }) : _crlfDelimiterBytes = Uint8List.fromList(
         ascii.encode('\r\n--$boundary'),
       ),
       _lfDelimiterBytes = Uint8List.fromList(ascii.encode('\n--$boundary')),
       _firstBoundaryBytes = Uint8List.fromList(ascii.encode('--$boundary')),
       _crlfFinder = BytePatternFinder(
         Uint8List.fromList(ascii.encode('\r\n--$boundary')),
       ),
       _lfFinder = BytePatternFinder(
         Uint8List.fromList(ascii.encode('\n--$boundary')),
       ),
       _firstBoundaryFinder = BytePatternFinder(
         Uint8List.fromList(ascii.encode('--$boundary')),
       );

  final StreamController<MultipartPart> _mainController;
  final int maxHeaderSize;
  final Uint8List _crlfDelimiterBytes;
  final Uint8List _lfDelimiterBytes;
  final Uint8List _firstBoundaryBytes;
  final BytePatternFinder _crlfFinder;
  final BytePatternFinder _lfFinder;
  final BytePatternFinder _firstBoundaryFinder;

  _ParserState _state = .start;
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  StreamController<Uint8List>? _activePartController;
  bool _isDisposed = false;

  void onData(List<int> chunk) {
    if (_isDisposed) return;
    _buffer.add(chunk);
    _processBuffer();
  }

  void onError(Object error, [StackTrace? stackTrace]) {
    if (_isDisposed) return;
    _fail(error, stackTrace);
  }

  void onDone() {
    if (_isDisposed) return;
    if (_state != .end) {
      _fail(
        const MultipartException('Unexpected end of multipart stream'),
        StackTrace.current,
      );
    } else {
      _closeMain();
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _closeActivePartWithError(
      const MultipartException('Multipart parser disposed'),
      StackTrace.current,
    );
  }

  void _fail(Object error, [StackTrace? stackTrace]) {
    if (_activePartController != null && !_activePartController!.isClosed) {
      _closeActivePartWithError(error, stackTrace);
      if (!_mainController.isClosed) {
        _mainController.close();
      }
    } else {
      if (!_mainController.isClosed) {
        _mainController.addError(error, stackTrace);
        _mainController.close();
      }
    }
    _isDisposed = true;
  }

  void _closeActivePartWithError(Object error, [StackTrace? stackTrace]) {
    if (_activePartController != null && !_activePartController!.isClosed) {
      _activePartController!.addError(error, stackTrace);
      _activePartController!.close();
      _activePartController = null;
    }
  }

  void _closeActivePart() {
    if (_activePartController != null && !_activePartController!.isClosed) {
      _activePartController!.close();
      _activePartController = null;
    }
  }

  void _closeMain() {
    _closeActivePart();
    if (!_mainController.isClosed) {
      _mainController.close();
    }
    _isDisposed = true;
  }

  void _processBuffer() {
    if (_buffer.isEmpty || _isDisposed) return;
    final bytes = _buffer.toBytes();
    var offset = 0;

    try {
      while (!_isDisposed && offset < bytes.length) {
        switch (_state) {
          case .start:
            final idx = _firstBoundaryFinder.indexOf(bytes, offset);
            if (idx == -1) {
              final holdBack = _firstBoundaryBytes.length + 2;
              final unconsumed = bytes.length - offset;
              if (unconsumed > holdBack) {
                offset = bytes.length - holdBack;
              }
              return;
            }

            offset = idx + _firstBoundaryBytes.length;
            _state = .boundaryTail;

          case .boundaryTail:
            if (bytes.length - offset < 2) {
              return;
            }

            if (bytes[offset] == 45 && bytes[offset + 1] == 45) {
              _state = .end;
              _closeMain();
              return;
            }

            offset = _skipBoundaryLineTail(bytes, offset);
            _state = .headers;

          case .headers:
            if (bytes.length - offset > maxHeaderSize) {
              _fail(
                const MultipartException(
                  'Multipart header section exceeds size limit',
                ),
              );
              return;
            }

            final headerEnd = _findHeaderEnd(bytes, offset);
            if (headerEnd == null) {
              return;
            }

            final headerBytes = Uint8List.sublistView(
              bytes,
              offset,
              headerEnd.index,
            );
            offset = headerEnd.index + headerEnd.length;

            _parseAndEmitPart(headerBytes);
            _state = .body;

          case .body:
            final crlfIdx = _crlfFinder.indexOf(bytes, offset);
            final lfIdx = _lfFinder.indexOf(bytes, offset);

            var idx = -1;
            var delimLen = 0;

            if (crlfIdx != -1 && (lfIdx == -1 || crlfIdx <= lfIdx)) {
              idx = crlfIdx;
              delimLen = _crlfDelimiterBytes.length;
            } else if (lfIdx != -1) {
              idx = lfIdx;
              delimLen = _lfDelimiterBytes.length;
            }

            if (idx != -1) {
              if (idx > offset) {
                _emitToActivePart(Uint8List.sublistView(bytes, offset, idx));
              }

              _closeActivePart();

              offset = idx + delimLen;
              _state = .boundaryTail;
            } else {
              final holdBack = _crlfDelimiterBytes.length + 6;
              final unconsumed = bytes.length - offset;
              if (unconsumed > holdBack) {
                final emitLength = unconsumed - holdBack;
                _emitToActivePart(
                  Uint8List.sublistView(bytes, offset, offset + emitLength),
                );
                offset += emitLength;
              }
              return;
            }

          case .end:
            _closeMain();
            return;
        }
      }
    } finally {
      if (offset > 0) {
        if (offset >= bytes.length) {
          _buffer.clear();
        } else {
          final remaining = Uint8List.sublistView(bytes, offset);
          _buffer.clear();
          _buffer.add(remaining);
        }
      }
    }
  }

  void _emitToActivePart(Uint8List chunk) {
    if (_activePartController != null && !_activePartController!.isClosed) {
      _activePartController!.add(chunk);
    }
  }

  int _skipBoundaryLineTail(Uint8List bytes, int offset) {
    var i = offset;
    while (i < bytes.length && (bytes[i] == 32 || bytes[i] == 9)) {
      i++;
    }
    if (i < bytes.length && bytes[i] == 13) i++; // \r
    if (i < bytes.length && bytes[i] == 10) i++; // \n
    return i;
  }

  void _parseAndEmitPart(Uint8List headerBytes) {
    final headersStr = utf8.decode(headerBytes, allowMalformed: true);
    final lines = headersStr.split(RegExp(r'\r?\n'));
    final headers = <String, String>{};

    for (final line in lines) {
      final colonIdx = line.indexOf(':');
      if (colonIdx != -1) {
        final key = line.substring(0, colonIdx).trim().toLowerCase();
        final value = line.substring(colonIdx + 1).trim();
        headers[key] = value;
      }
    }

    String? name;
    String? filename;

    final contentDisposition = headers['content-disposition'];
    if (contentDisposition != null) {
      try {
        final parsed = HeaderValue.parse(contentDisposition);
        name = parsed.parameters['name'];
        final rawFilename = parsed.parameters['filename'];
        if (rawFilename != null) {
          filename = rawFilename.split('/').last.split(r'\').last;
        }
      } catch (_) {}
    }

    final partController = StreamController<Uint8List>();
    _activePartController = partController;

    final part = MultipartPart(
      name: name,
      filename: filename,
      contentType: headers['content-type'],
      headers: Map.unmodifiable(headers),
      bytes: partController.stream,
    );

    _mainController.add(part);
  }

  _HeaderEnd? _findHeaderEnd(Uint8List bytes, int offset) {
    final max = bytes.length - 1;
    for (var i = offset; i < max; i++) {
      if (i <= bytes.length - 4 &&
          bytes[i] == 13 &&
          bytes[i + 1] == 10 &&
          bytes[i + 2] == 13 &&
          bytes[i + 3] == 10) {
        return (index: i, length: 4);
      }
      if (bytes[i] == 10 && bytes[i + 1] == 10) {
        return (index: i, length: 2);
      }
    }
    return null;
  }
}

typedef _HeaderEnd = ({int index, int length});

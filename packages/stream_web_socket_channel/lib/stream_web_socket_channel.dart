import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

abstract final class WebSocketOpcode {
  static const int continuation = 0x0;
  static const int text = 0x1;
  static const int binary = 0x2;
  static const int unknown = 0x3;
  static const int close = 0x8;
  static const int ping = 0x9;
  static const int pong = 0xA;
}

/// Options for WebSocket permessage-deflate compression (RFC 7692).
class WebSocketDeflateOptions {
  const WebSocketDeflateOptions({
    this.enabled = true,
    this.serverNoContextTakeover = false,
    this.clientNoContextTakeover = false,
  });

  /// No compression (default, zero performance overhead).
  static const none = WebSocketDeflateOptions(enabled: false);

  /// Default permessage-deflate configuration per RFC 7692.
  static const defaultConfig = WebSocketDeflateOptions();

  final bool enabled;
  final bool serverNoContextTakeover;
  final bool clientNoContextTakeover;
}

/// A pure Dart [WebSocketChannel] implementation for server-side
/// WebSocket connections directly over a raw byte stream channel.
class StreamWebSocketChannel extends StreamChannelMixin<Object?>
    implements WebSocketChannel {
  StreamWebSocketChannel(
    StreamChannel<List<int>> channel, {
    this.protocol,
    this.deflateOptions = WebSocketDeflateOptions.none,
    this.maxMessageSize,
  }) : _outputSink = channel.sink {
    _incoming = StreamController<Object?>(
      sync: true,
      onListen: _resumeUnlistened,
      onPause: () {
        _isPausedByReader = true;
        _inputSubscription.pause();
      },
      onResume: () {
        _isPausedByReader = false;
        _inputSubscription.resume();
      },
      onCancel: _discardIncoming,
    );
    _sink = _StreamWebSocketSink(this);
    // Reading follows [stream]'s listener: a paused listener pauses the
    // input, so a peer cannot fill memory faster than the handler consumes.
    _inputSubscription = channel.stream.listen(
      _onBytesReceived,
      onError: (Object error, StackTrace stackTrace) {
        if (!_incoming.isClosed) _incoming.addError(error, stackTrace);
      },
      onDone: _onInputDone,
    );
  }

  /// How long to wait for the peer's close frame after sending ours.
  static const _closeTimeout = Duration(seconds: 5);

  /// Outgoing bytes after which sending waits for the socket to drain.
  static const int _flushThreshold = 64 * 1024;

  /// Message bytes kept for a [stream] nobody listens to yet; past this the
  /// input is paused until a listener comes.
  static const int _maxUnlistenedBytes = 1024 * 1024;

  final StreamSink<List<int>> _outputSink;
  late final StreamSubscription<List<int>> _inputSubscription;
  late final StreamController<Object?> _incoming;
  late final _StreamWebSocketSink _sink;

  int _unlistenedBytes = 0;

  /// The input is paused: [_maxUnlistenedBytes] reached without a listener.
  bool _isPausedUnlistened = false;

  /// [stream]'s listener is paused, and so is the input.
  bool _isPausedByReader = false;

  /// Data messages are dropped: nobody will read them.
  bool _isDiscarding = false;
  bool _isOutputClosed = false;
  Timer? _closeTimer;
  int _unflushedBytes = 0;

  /// The output is flushing; see [_write].
  Future<void>? _flushing;
  final List<List<int>> _queuedWrites = [];

  @override
  final String? protocol;
  final WebSocketDeflateOptions deflateOptions;
  final int? maxMessageSize;

  RawZLibFilter? _inflater;
  RawZLibFilter? _deflater;
  bool _isCurrentMessageCompressed = false;

  final _Uint8Buffer _buffer = _Uint8Buffer();
  int _readOffset = 0;
  int? _currentOpcode;
  final BytesBuilder _fragmentBuffer = BytesBuilder(copy: false);

  // Scratch buffer for writing WebSocket frame headers without allocations.
  final Uint8List _headerScratch = Uint8List(10);

  bool _isCloseSent = false;

  @override
  int? get closeCode => _closeCode;
  int? _closeCode;

  @override
  String? get closeReason => _closeReason;
  String? _closeReason;

  int? _localCloseCode;
  String? _localCloseReason;

  final _readyCompleter = Completer<void>()..complete();

  @override
  Future<void> get ready => _readyCompleter.future;

  @override
  Stream<Object?> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  void _resumeUnlistened() {
    if (!_isPausedUnlistened) return;
    _isPausedUnlistened = false;
    _inputSubscription.resume();
  }

  /// Keeps reading (for control frames and the peer's close) without
  /// delivering data messages.
  void _discardIncoming() {
    _isDiscarding = true;
    if (_isPausedByReader) {
      _isPausedByReader = false;
      _inputSubscription.resume();
    }
    _resumeUnlistened();
  }

  void _onBytesReceived(List<int> chunk) {
    _buffer.addAll(chunk);
    _parseFrames();
  }

  void _parseFrames() {
    while (_buffer.length - _readOffset >= 2) {
      final b0 = _buffer[_readOffset];
      final b1 = _buffer[_readOffset + 1];

      final fin = (b0 & 0x80) != 0;
      final opcode = b0 & 0x0F;
      final masked = (b1 & 0x80) != 0;

      // RSV bits check: RSV1 is allowed ONLY on initial text/binary frames if deflate is enabled (RFC 7692 §7.2.3). RSV2/3 MUST be 0.
      final rsv1 = (b0 & 0x40) != 0;
      final rsv23 = (b0 & 0x30) != 0;
      final isInitialDataFrame =
          opcode == WebSocketOpcode.text || opcode == WebSocketOpcode.binary;

      if (rsv23 || (rsv1 && (!deflateOptions.enabled || !isInitialDataFrame))) {
        _closeWithError(1002, 'RSV bits must be zero');
        return;
      }

      // Client MUST mask all frames sent to server
      if (!masked) {
        _closeWithError(1002, 'Client frames must be masked');
        return;
      }

      var payloadLen = b1 & 0x7F;

      // Control frames MUST NOT be fragmented & payload <= 125
      final isControl = (opcode & 0x08) != 0;
      if (isControl) {
        if (!fin) {
          _closeWithError(1002, 'Control frame cannot be fragmented');
          return;
        }
        if (payloadLen > 125) {
          _closeWithError(
            1002,
            'Control frame payload cannot exceed 125 bytes',
          );
          return;
        }
      }

      var headerLen = 2;
      if (payloadLen == 126) {
        if (_buffer.length - _readOffset < 4) return;
        payloadLen = (_buffer[_readOffset + 2] << 8) | _buffer[_readOffset + 3];
        if (payloadLen < 126) {
          _closeWithError(1002, 'Non-minimal payload length encoding');
          return;
        }
        headerLen = 4;
      } else if (payloadLen == 127) {
        if (_buffer.length - _readOffset < 10) return;
        if ((_buffer[_readOffset + 2] & 0x80) != 0) {
          _closeWithError(1002, 'MSB of 64-bit length must be zero');
          return;
        }
        payloadLen = 0;
        for (var i = 2; i < 10; i++) {
          payloadLen = (payloadLen << 8) | _buffer[_readOffset + i];
        }
        if (payloadLen <= 65535) {
          _closeWithError(1002, 'Non-minimal payload length encoding');
          return;
        }
        headerLen = 10;
      }

      if (!isControl &&
          maxMessageSize != null &&
          payloadLen > maxMessageSize!) {
        _closeWithError(
          1009,
          'Frame payload length $payloadLen exceeds '
          'limit of $maxMessageSize bytes',
        );
        return;
      }

      if (masked) {
        headerLen += 4;
      }

      final totalFrameLen = headerLen + payloadLen;
      if (_buffer.length - _readOffset < totalFrameLen) return;

      // Unmask payload directly
      final payload = Uint8List(payloadLen);
      final payloadOffset = _readOffset + headerLen;

      if (masked) {
        final maskOffset = _readOffset + headerLen - 4;
        final k0 = _buffer[maskOffset];
        final k1 = _buffer[maskOffset + 1];
        final k2 = _buffer[maskOffset + 2];
        final k3 = _buffer[maskOffset + 3];

        var i = 0;
        final mask32 = k0 | (k1 << 8) | (k2 << 16) | (k3 << 24);

        if (payloadLen >= 16 &&
            (payload.offsetInBytes & 15) == 0 &&
            ((_buffer._data.offsetInBytes + payloadOffset) & 15) == 0) {
          final maskBlock = Int32x4(mask32, mask32, mask32, mask32);
          final blockCount = payloadLen ~/ 16;
          final payloadBlock = Int32x4List.view(
            payload.buffer,
            payload.offsetInBytes,
            blockCount,
          );
          final bufferBlock = Int32x4List.view(
            _buffer._data.buffer,
            _buffer._data.offsetInBytes + payloadOffset,
            blockCount,
          );

          for (var b = 0; b < blockCount; b++) {
            payloadBlock[b] = bufferBlock[b] ^ maskBlock;
          }
          i = blockCount * 16;
        } else if (payloadLen >= 4 &&
            (payload.offsetInBytes & 3) == 0 &&
            ((_buffer._data.offsetInBytes + payloadOffset) & 3) == 0) {
          final wordCount = payloadLen ~/ 4;
          final payload32 = Uint32List.view(
            payload.buffer,
            payload.offsetInBytes,
            wordCount,
          );
          final buffer32 = Uint32List.view(
            _buffer._data.buffer,
            _buffer._data.offsetInBytes + payloadOffset,
            wordCount,
          );

          for (var w = 0; w < wordCount; w++) {
            payload32[w] = buffer32[w] ^ mask32;
          }
          i = wordCount * 4;
        }

        final maskKey = [k0, k1, k2, k3];
        for (; i < payloadLen; i++) {
          payload[i] = _buffer[payloadOffset + i] ^ maskKey[i & 3];
        }
      } else {
        payload.setRange(0, payloadLen, _buffer._data, payloadOffset);
      }

      _readOffset += totalFrameLen;
      if (_readOffset == _buffer.length) {
        _buffer.clear();
        _readOffset = 0;
      } else if (_readOffset > 4096) {
        _buffer.removeRange(0, _readOffset);
        _readOffset = 0;
      }

      if (opcode != WebSocketOpcode.continuation) {
        _isCurrentMessageCompressed = rsv1;
      }

      _processFrame(fin: fin, opcode: opcode, payload: payload);
    }
  }

  void _processFrame({
    required bool fin,
    required int opcode,
    required Uint8List payload,
  }) {
    switch (opcode) {
      case WebSocketOpcode.continuation:
        if (_currentOpcode == null) {
          _closeWithError(1002, 'Continuation frame without initial frame');
          return;
        }
        if (maxMessageSize != null &&
            _fragmentBuffer.length + payload.length > maxMessageSize!) {
          _closeWithError(
            1009,
            'Exceeded maximum message size of $maxMessageSize bytes',
          );
          return;
        }
        _fragmentBuffer.add(payload);
        if (fin) {
          var fullPayload = _fragmentBuffer.takeBytes();
          if (_isCurrentMessageCompressed) {
            try {
              fullPayload = _decompressMessage(fullPayload);
            } on _DecompressLimitException {
              return;
            } catch (_) {
              _closeWithError(1007, 'Invalid compressed payload');
              return;
            }
            _isCurrentMessageCompressed = false;
          }
          _dispatchMessage(_currentOpcode!, fullPayload);
          _currentOpcode = null;
        }
      case WebSocketOpcode.text:
      case WebSocketOpcode.binary:
        if (_currentOpcode != null) {
          _closeWithError(
            1002,
            'Received data frame while fragmentation in progress',
          );
          return;
        }
        if (!fin) {
          if (maxMessageSize != null && payload.length > maxMessageSize!) {
            _closeWithError(
              1009,
              'Exceeded maximum message size of $maxMessageSize bytes',
            );
            return;
          }
          _currentOpcode = opcode;
          _fragmentBuffer.add(payload);
        } else {
          var finalPayload = payload;
          if (_isCurrentMessageCompressed) {
            try {
              finalPayload = _decompressMessage(payload);
            } on _DecompressLimitException {
              return;
            } catch (_) {
              _closeWithError(1007, 'Invalid compressed payload');
              return;
            }
            _isCurrentMessageCompressed = false;
          }
          _dispatchMessage(opcode, finalPayload);
        }
      case WebSocketOpcode.close:
        if (payload.length == 1) {
          _closeWithError(1002, 'Invalid close payload length');
          return;
        }
        int? code;
        String? reason;
        if (payload.length >= 2) {
          code = (payload[0] << 8) | payload[1];
          if (code < 1000 ||
              code > 4999 ||
              code == 1004 ||
              code == 1005 ||
              code == 1006 ||
              (code >= 1014 && code <= 2999)) {
            _closeWithError(1002, 'Invalid close status code: $code');
            return;
          }
          if (payload.length > 2) {
            try {
              reason = utf8.decode(payload.sublist(2));
            } catch (_) {
              _closeWithError(1007, 'Invalid UTF-8 in close reason');
              return;
            }
          }
        }
        _closeCode = code ?? 1005;
        _closeReason = reason;
        _sendCloseFrame(code, reason);
        _incoming.close();
        _inputSubscription.cancel();
        // Handshake complete; the server closes TCP first (RFC 6455 §7.1.1).
        _closeOutput();
      case WebSocketOpcode.ping:
        _sendFrame(WebSocketOpcode.pong, payload);
      case WebSocketOpcode.pong:
        break;
      default:
        _closeWithError(1002, 'Unknown opcode: $opcode');
    }
  }

  Uint8List _decompressMessage(Uint8List compressed) {
    _inflater ??= RawZLibFilter.inflateFilter(raw: true);
    final input = Uint8List(compressed.length + 4);
    input.setRange(0, compressed.length, compressed);
    input[compressed.length] = 0x00;
    input[compressed.length + 1] = 0x00;
    input[compressed.length + 2] = 0xff;
    input[compressed.length + 3] = 0xff;

    _inflater!.process(input, 0, input.length);
    final builder = BytesBuilder(copy: false);
    var decompressedSize = 0;
    while (true) {
      final out = _inflater!.processed();
      if (out == null) break;

      decompressedSize += out.length;
      if (maxMessageSize != null && decompressedSize > maxMessageSize!) {
        _closeWithError(
          1009,
          'Exceeded maximum message size of $maxMessageSize bytes',
        );
        throw const _DecompressLimitException();
      }

      builder.add(out);
    }
    if (deflateOptions.clientNoContextTakeover) {
      _inflater = null;
    }
    return builder.takeBytes();
  }

  Uint8List _compressMessage(Uint8List rawPayload) {
    _deflater ??= RawZLibFilter.deflateFilter(raw: true);
    _deflater!.process(rawPayload, 0, rawPayload.length);
    final builder = BytesBuilder(copy: false);
    while (true) {
      final out = _deflater!.processed();
      if (out == null) break;
      builder.add(out);
    }
    var compressed = builder.takeBytes();
    if (compressed.length >= 4 &&
        compressed[compressed.length - 4] == 0x00 &&
        compressed[compressed.length - 3] == 0x00 &&
        compressed[compressed.length - 2] == 0xff &&
        compressed[compressed.length - 1] == 0xff) {
      compressed = compressed.sublist(0, compressed.length - 4);
    }
    if (deflateOptions.serverNoContextTakeover) {
      _deflater = null;
    }
    return compressed;
  }

  void _dispatchMessage(int opcode, Uint8List payload) {
    if (opcode == WebSocketOpcode.text) {
      final String text;
      try {
        text = utf8.decode(payload);
      } on FormatException {
        _closeWithError(1007, 'Invalid UTF-8 payload');
        return;
      }
      _deliver(text, payload.length);
    } else {
      _deliver(payload, payload.length);
    }
  }

  void _deliver(Object message, int size) {
    if (_isDiscarding) return;
    _incoming.add(message);
    if (_incoming.hasListener || _isPausedUnlistened) return;
    _unlistenedBytes += size;
    if (_unlistenedBytes >= _maxUnlistenedBytes) {
      _isPausedUnlistened = true;
      _inputSubscription.pause();
    }
  }

  void _sendFrame(
    int opcode,
    Uint8List payload, {
    bool rsv1 = false,
  }) {
    final len = payload.length;
    int headerLen;

    _headerScratch[0] = (rsv1 ? 0xC0 : 0x80) | (opcode & 0x0F);

    if (len <= 125) {
      _headerScratch[1] = len;
      headerLen = 2;
    } else if (len <= 65535) {
      _headerScratch[1] = 126;
      _headerScratch[2] = (len >> 8) & 0xFF;
      _headerScratch[3] = len & 0xFF;
      headerLen = 4;
    } else {
      _headerScratch[1] = 127;
      for (var i = 0; i < 8; i++) {
        _headerScratch[2 + i] = (len >> ((7 - i) * 8)) & 0xFF;
      }
      headerLen = 10;
    }

    if (_isOutputClosed) return;
    _write(_headerScratch.sublist(0, headerLen));
    if (len > 0) {
      _write(payload);
    }
    _unflushedBytes += headerLen + len;
  }

  void _sendCloseFrame([int? code, String? reason]) {
    if (_isCloseSent) return;
    _isCloseSent = true;
    final payload = <int>[];
    final isWireCode =
        code != null &&
        code != 1004 &&
        code != 1005 &&
        code != 1006 &&
        code != 1015 &&
        code >= 1000 &&
        code <= 4999 &&
        !(code >= 1014 && code <= 2999);

    if (isWireCode) {
      payload.add((code >> 8) & 0xFF);
      payload.add(code & 0xFF);
      if (reason != null && reason.isNotEmpty) {
        payload.addAll(utf8.encode(reason));
      }
    }
    _sendFrame(WebSocketOpcode.close, Uint8List.fromList(payload));
  }

  void _closeWithError(int code, String reason) {
    _closeCode = code;
    _closeReason = reason;
    _sendCloseFrame(code, reason);
    if (!_incoming.isClosed) {
      _incoming
        ..addError(WebSocketChannelException(reason))
        ..close();
    }
    _inputSubscription.cancel();
    _closeOutput();
  }

  void _onInputDone() {
    _closeCode ??= 1006;
    _incoming.close();
    _closeOutput();
  }

  /// Called when the sink is closed and our close frame is sent: waits for
  /// the peer's close frame, then closes the connection.
  void _onSinkClosed() {
    if (_isOutputClosed) return;
    if (!_incoming.hasListener) _discardIncoming();
    _closeTimer = Timer(_closeTimeout, _closeOutput);
  }

  /// Closes the underlying connection.
  void _closeOutput() {
    if (_isOutputClosed) return;
    _isOutputClosed = true;
    _closeTimer?.cancel();
    // An IOSink cannot be closed while flushing; that is done after it.
    if (_flushing == null) _outputSink.close().ignore();
  }

  /// Waits for the output to drain once enough bytes are queued.
  Future<void>? _drainIfNeeded() {
    if (_unflushedBytes < _flushThreshold) return null;
    _unflushedBytes = 0;
    final output = _outputSink;
    if (output is! IOSink || _isOutputClosed) return null;
    return _flushing = output
        .flush()
        .then<void>((_) {}, onError: (Object _) {})
        .whenComplete(() {
          _flushing = null;
          try {
            _queuedWrites.forEach(output.add);
          } on Object {
            // The connection is gone.
          }
          _queuedWrites.clear();
          if (_isOutputClosed) output.close().ignore();
        });
  }

  /// Writes [bytes], or queues them while an IOSink is flushing: it does not
  /// accept data meanwhile (control frames are sent during a flush).
  void _write(List<int> bytes) {
    if (_flushing != null) {
      _queuedWrites.add(bytes);
    } else {
      _outputSink.add(bytes);
    }
  }

  void _sendMessage(Object? message) {
    int opcode;
    Uint8List payload;

    if (message is String) {
      opcode = WebSocketOpcode.text;
      payload = Uint8List.fromList(utf8.encode(message));
    } else if (message is Uint8List) {
      opcode = WebSocketOpcode.binary;
      payload = message;
    } else if (message is List<int>) {
      opcode = WebSocketOpcode.binary;
      payload = Uint8List.fromList(message);
    } else {
      throw ArgumentError(
        'Unsupported WebSocket message type: ${message.runtimeType}',
      );
    }

    if (deflateOptions.enabled && payload.isNotEmpty) {
      final compressed = _compressMessage(payload);
      _sendFrame(opcode, compressed, rsv1: true);
    } else {
      _sendFrame(opcode, payload);
    }
  }
}

/// Legacy alias for [StreamWebSocketChannel].
@Deprecated('Use StreamWebSocketChannel instead')
typedef RawWebSocketChannel = StreamWebSocketChannel;

class _StreamWebSocketSink implements WebSocketSink {
  _StreamWebSocketSink(this._channel) {
    _done.future.ignore();
    late final StreamSubscription<Object?> subscription;
    subscription = _outgoing.stream.listen(
      (message) {
        _channel._sendMessage(message);
        // Pausing the controller also pauses a stream given to [addStream].
        if (_channel._drainIfNeeded() case final drained?) {
          subscription.pause(drained);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        subscription.cancel();
        _finish(error, stackTrace);
      },
      onDone: _finish,
    );
  }

  final StreamWebSocketChannel _channel;
  final _outgoing = StreamController<Object?>(sync: true);
  final _done = Completer<void>();

  /// Sends the close frame and completes [done], with [error] if given.
  void _finish([Object? error, StackTrace? stackTrace]) {
    if (_done.isCompleted) return;
    _channel
      .._sendCloseFrame(_channel._localCloseCode, _channel._localCloseReason)
      .._onSinkClosed();
    if (error != null) {
      _done.completeError(error, stackTrace);
    } else {
      _done.complete();
    }
  }

  @override
  void add(dynamic data) => _outgoing.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _outgoing.addError(error, stackTrace);

  @override
  Future<dynamic> addStream(Stream<dynamic> stream) =>
      _outgoing.addStream(stream);

  @override
  Future<dynamic> get done => _done.future;

  @override
  Future<dynamic> close([int? closeCode, String? closeReason]) {
    _channel._localCloseCode = closeCode;
    _channel._localCloseReason = closeReason;
    if (!_outgoing.isClosed) _outgoing.close().ignore();
    return _done.future;
  }
}

class _Uint8Buffer {
  Uint8List _data = Uint8List(1024);
  int _length = 0;

  int get length => _length;

  int operator [](int index) => _data[index];

  void addAll(List<int> bytes) {
    final required = _length + bytes.length;
    if (required > _data.length) {
      var newCap = _data.length * 2;
      while (newCap < required) {
        newCap *= 2;
      }
      final newData = Uint8List(newCap);
      newData.setRange(0, _length, _data);
      _data = newData;
    }
    if (bytes is Uint8List) {
      _data.setRange(_length, required, bytes);
    } else {
      for (var i = 0; i < bytes.length; i++) {
        _data[_length + i] = bytes[i];
      }
    }
    _length = required;
  }

  void removeRange(int start, int end) {
    final count = end - start;
    if (count == _length) {
      _length = 0;
    } else {
      _data.setRange(0, _length - count, _data, end);
      _length -= count;
    }
  }

  void clear() {
    _length = 0;
  }
}

class _DecompressLimitException implements Exception {
  const _DecompressLimitException();
}

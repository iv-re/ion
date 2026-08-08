import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ctx/ctx.dart';
import 'package:ion_web/ion_web.dart';
import 'package:ion_web/src/http/http.dart';
import 'package:sl/sl.dart';
import 'package:stream_channel/stream_channel.dart';

final _emptyBytes = Uint8List(0);
final _errorResponseCache = <HttpStatusCode, Uint8List>{};
final _continueResponseBytes = Uint8List.fromList(
  ascii.encode('HTTP/1.1 100 Continue\r\n\r\n'),
);

/// On keep-alive connections the socket is not flushed after every
/// response (that would gate each pipelined request on the OS write
/// draining). Instead we flush once this many unflushed bytes have
/// accumulated, bounding buffering for a fast handler + slow client to
/// roughly this value plus one response.
const int _flushThreshold = 256 * 1024;

Uri _buildEffectiveUri(
  Uri requestUri,
  TypedHeaders headers, {
  bool isSecure = false,
}) {
  if (requestUri.hasScheme) return requestUri;

  final hostHeader = headers.host;
  final host = hostHeader?.host ?? 'localhost';
  final port = hostHeader?.port;

  return requestUri.replace(
    scheme: isSecure ? 'https' : 'http',
    host: host,
    port: port,
  );
}

enum HttpConnectionState {
  newConnection,
  active,
  idle,
  upgraded,
  closed,
}

class HttpConnection {
  HttpConnection(
    this.socket, {
    required this._handler,
    this._logger,
    this._readHeaderTimeout,
    this._readBodyTimeout,
    this._writeTimeout,
    this._idleTimeout,
    int maxHeaderSize = 64 * 1024,
    int maxHeaderCount = 500,
  }) : _parser = HttpParser(
         maxHeaderSize: maxHeaderSize,
         maxHeaderCount: maxHeaderCount,
       ),
       remoteAddress = socket.remoteAddress,
       remotePort = socket.remotePort {
    socket.done.catchError((Object _) {});
  }

  final Socket socket;
  final Handler _handler;
  final Logger? _logger;

  final Duration? _readHeaderTimeout;
  final Duration? _readBodyTimeout;
  final Duration? _writeTimeout;
  final Duration? _idleTimeout;

  final InternetAddress remoteAddress;
  final int remotePort;

  late final _connectionInfo = ConnectionInfo(
    remoteAddress: remoteAddress,
    remotePort: remotePort,
    localPort: socket.port,
  );

  StreamSubscription<Uint8List>? _subscription;
  final HttpParser _parser;

  BodyController? _bodyController;
  Completer<void>? _currentBodyDone;
  ContextCancelFn? _currentRequestCancel;
  Timer? _headerTimer;
  Timer? _bodyTimer;
  Timer? _writeTimer;
  Timer? _idleTimer;
  var _readyForNextRequest = Completer<void>()..complete();

  StreamController<Uint8List>? _upgradeController;

  HttpConnectionState _state = HttpConnectionState.newConnection;
  HttpConnectionState get state => _state;

  final _doneCompleter = Completer<void>();
  Future<void> get done => _doneCompleter.future;

  var _isShuttingDown = false;
  var _forceClose = false;
  bool get _isDestroyed => _state == .closed;
  var _clientClosed = false;
  var _responseSent = false;
  var _unflushedBytes = 0;
  var _canSend100Continue = false;

  void start() {
    _startIdleTimer();
    _subscription = socket.listen(
      _onData,
      onDone: () {
        if (_upgradeController != null) {
          _upgradeController?.close();
        } else {
          _clientClosed = true;
          _currentRequestCancel?.call();
          if (_bodyController != null && !_bodyController!.isDone) {
            _bodyController!.addError(
              const BodyControllerException('Incomplete body'),
            );
            _bodyController!.close();
            _forceClose = true;
            if (_currentBodyDone != null && !_currentBodyDone!.isCompleted) {
              _currentBodyDone!.complete();
            }
          } else {
            _bodyController?.close();
          }
        }
      },
      onError: (Object error) {
        if (_upgradeController != null) {
          _upgradeController?.addError(error);
        } else {
          _currentRequestCancel?.call();
          _destroy();
        }
      },
      cancelOnError: true,
    );
  }

  void _startIdleTimer() {
    if (!_isDestroyed && !_clientClosed) {
      _idleTimer?.cancel();
      final timeout = _idleTimeout ?? _readHeaderTimeout;
      if (timeout != null) {
        _idleTimer = Timer(timeout, _destroy);
      }
    }
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  void _startHeaderTimer() {
    if (_readHeaderTimeout != null && !_isDestroyed && !_clientClosed) {
      _headerTimer?.cancel();
      _headerTimer = Timer(_readHeaderTimeout, _destroy);
    }
  }

  void _cancelHeaderTimer() {
    _headerTimer?.cancel();
    _headerTimer = null;
  }

  void _startBodyTimer() {
    if (_readBodyTimeout != null && !_isDestroyed && !_clientClosed) {
      _bodyTimer?.cancel();
      _bodyTimer = Timer(_readBodyTimeout, _destroy);
    }
  }

  void _cancelBodyTimer() {
    _bodyTimer?.cancel();
    _bodyTimer = null;
  }

  void _startWriteTimer() {
    if (_writeTimeout != null && !_isDestroyed && !_clientClosed) {
      _writeTimer?.cancel();
      _writeTimer = Timer(_writeTimeout, _destroy);
    }
  }

  void _cancelWriteTimer() {
    _writeTimer?.cancel();
    _writeTimer = null;
  }

  void _flushCloseDestroy() {
    socket.flush().then(
      (_) => socket.close().then(
        (_) => _destroy(),
        onError: (Object _) => _destroy(),
      ),
      onError: (Object _) => _destroy(),
    );
  }

  void shutdown() {
    _isShuttingDown = true;
    if (_state == .idle || _state == .newConnection) {
      _flushCloseDestroy();
    }
  }

  void _sendErrorAndClose(HttpStatusCode status) {
    try {
      final bytes = _errorResponseCache[status] ??= Uint8List.fromList(
        ascii.encode(
          'HTTP/1.1 ${status.value} ${status.reasonPhrase}\r\n'
          'Connection: close\r\n\r\n',
        ),
      );
      socket.add(bytes);
      _flushCloseDestroy();
    } on SocketException {
      _destroy();
    }
  }

  void _send100Continue() {
    if (_canSend100Continue &&
        !_isDestroyed &&
        !_clientClosed &&
        !_responseSent) {
      _canSend100Continue = false;
      try {
        socket.add(_continueResponseBytes);
        socket.flush();
      } catch (_) {}
    }
  }

  Future<void> _onData(Uint8List data) async {
    if (_upgradeController != null) {
      _upgradeController?.add(data);
      return;
    }
    if (_isDestroyed || _clientClosed) return;

    try {
      var currentData = data;
      _cancelIdleTimer();
      if (_headerTimer == null && _state != .active) {
        _startHeaderTimer();
      }

      while (currentData.isNotEmpty) {
        if (_upgradeController != null) {
          _upgradeController?.add(currentData);
          return;
        }
        if (_isDestroyed) return;

        if (_bodyController != null) {
          currentData = _bodyController!.add(currentData);
          if (currentData.isNotEmpty || _bodyController!.isDone) {
            _bodyController = null;
            continue;
          }
          break;
        }

        if (!_readyForNextRequest.isCompleted) {
          _subscription?.pause(
            _readyForNextRequest.future.then((_) {
              if (!_isDestroyed && !_clientClosed) {
                _onData(currentData);
              }
            }),
          );
          return;
        }

        final requestHead = _parser.feed(currentData);
        if (requestHead == null) break;

        _state = .active;
        _cancelHeaderTimer();
        _readyForNextRequest = Completer<void>();
        final bodyDone = Completer<void>();

        final consumedInHeaders = requestHead.consumedBytesInLastChunk;
        final remainingInChunk = consumedInHeaders == currentData.length
            ? _emptyBytes
            : Uint8List.sublistView(currentData, consumedInHeaders);

        final typedHeaders = TypedHeaders(requestHead.headerSlices);

        // Unsupported HTTP version (RFC 9112 Sec 2.3)
        if (requestHead.version != .http10 && requestHead.version != .http11) {
          _sendErrorAndClose(.httpVersionNotSupported);
          return;
        }

        // Malformed or duplicate Content-Length headers (RFC 9112 Sec 6.3)
        if (typedHeaders.hasContentLengthConflict) {
          _sendErrorAndClose(.badRequest);
          return;
        }

        // RFC 9112 Sec 6.1: Invalid or empty Transfer-Encoding header
        if (typedHeaders.isTransferEncodingInvalid) {
          _sendErrorAndClose(.badRequest);
          return;
        }

        // RFC 9112 Sec 6.1: Conflict if both Content-Length
        // and Transfer-Encoding are present
        if (typedHeaders.parsedContentLength != null &&
            typedHeaders.hasTransferEncoding) {
          _sendErrorAndClose(.badRequest);
          return;
        }

        // Host validation for HTTP/1.1
        if (requestHead.version == .http11) {
          if (typedHeaders.hasHostConflict) {
            _sendErrorAndClose(.badRequest);
            return;
          }
          final hostHeader = typedHeaders.host;
          if (hostHeader == null || !hostHeader.isValid) {
            _sendErrorAndClose(.badRequest);
            return;
          }
        }

        // Unsupported / Non-final Transfer-Encoding (RFC 9112 Sec 6.3)
        if (typedHeaders.hasTransferEncoding) {
          if (typedHeaders.hasNonFinalChunkedConflict) {
            _sendErrorAndClose(.badRequest);
            return;
          }
          if (!typedHeaders.isChunkedTransferEncoding) {
            _sendErrorAndClose(.notImplemented);
            return;
          }
        }

        // Restricted methods: CONNECT and TRACE
        if (requestHead.method == .connect || requestHead.method == .trace) {
          _sendErrorAndClose(.methodNotAllowed);
          return;
        }

        final contentLength = typedHeaders.parsedContentLength ?? 0;
        final isChunked = typedHeaders.isChunkedTransferEncoding;

        // OPTIONS request cannot have a body
        if (requestHead.method == .options &&
            (contentLength > 0 || isChunked)) {
          _sendErrorAndClose(.badRequest);
          return;
        }

        Uri effectiveUri;
        try {
          effectiveUri = _buildEffectiveUri(
            requestHead.uri,
            typedHeaders,
            isSecure: socket is SecureSocket,
          );
        } on FormatException {
          _sendErrorAndClose(.badRequest);
          return;
        }

        _canSend100Continue = false;
        if (typedHeaders.has(HttpHeader.expect)) {
          if (typedHeaders.expect != null) {
            if (requestHead.version == .http11 &&
                (contentLength > 0 || isChunked)) {
              _canSend100Continue = true;
            }
          } else {
            _sendErrorAndClose(.expectationFailed);
            return;
          }
        }

        Stream<Uint8List> requestBody;
        if (isChunked) {
          _bodyController = ChunkedBodyController(
            onDone: () {
              if (!bodyDone.isCompleted) bodyDone.complete();
            },
            onPause: () => _subscription?.pause(),
            onResume: () => _subscription?.resume(),
            onListen: _canSend100Continue ? _send100Continue : null,
          );
          requestBody = _bodyController!.stream;
          currentData = _bodyController!.add(remainingInChunk);
        } else if (contentLength > 0) {
          _bodyController = FixedLengthBodyController(
            contentLength,
            onDone: () {
              if (!bodyDone.isCompleted) bodyDone.complete();
            },
            onPause: () => _subscription?.pause(),
            onResume: () => _subscription?.resume(),
            onListen: _canSend100Continue ? _send100Continue : null,
          );
          requestBody = _bodyController!.stream;
          currentData = _bodyController!.add(remainingInChunk);
        } else {
          requestBody = const Stream<Uint8List>.empty();
          currentData = remainingInChunk;
          bodyDone.complete();
        }

        if (!bodyDone.isCompleted) {
          _startBodyTimer();
          unawaited(
            bodyDone.future.then((_) {
              _cancelBodyTimer();
            }),
          );
        }

        if (_bodyController?.isDone ?? false) {
          _bodyController = null;
        }

        final (reqCtx, cancelReqCtx) = const Context.empty().withCancel();
        _currentRequestCancel = cancelReqCtx;

        final request = Request(
          requestBody,
          method: requestHead.method,
          uri: effectiveUri,
          version: requestHead.version,
          headers: typedHeaders,
          connectionInfo: _connectionInfo,
          ctx: reqCtx,
        );

        _currentBodyDone = bodyDone;

        try {
          _responseSent = false;
          final rawResponse = _handler(request);
          var response = rawResponse is Response
              ? rawResponse
              : await rawResponse;

          if (response case final ResolvableResponse resolvable) {
            final resResult = resolvable.resolve(request);
            response = resResult is Response ? resResult : await resResult;
          }

          _startWriteTimer();
          try {
            if (response.onUpgrade case final onUpgrade?) {
              _responseSent = true;
              final headBytes = HttpResponseWriter.writeUpgradeHead(
                socket,
                headers: response.headers,
              );
              _unflushedBytes += headBytes;

              _state = .upgraded;
              _cancelIdleTimer();
              _cancelHeaderTimer();
              _cancelBodyTimer();
              _cancelWriteTimer();
              await socket.flush();
              _upgradeController = StreamController<Uint8List>(sync: true);
              if (currentData.isNotEmpty) {
                _upgradeController!.add(currentData);
              }
              final channel = StreamChannel<List<int>>(
                _upgradeController!.stream,
                socket,
              );
              await onUpgrade(channel);
              return;
            }

            final writeResult = HttpResponseWriter.write(
              socket,
              method: request.method,
              keepAlive: request.keepAlive && !_forceClose && !_isShuttingDown,
              status: response.status.value,
              headers: response.headers,
              body: response.body,
            );
            final (bytesWritten, keepAlive) = writeResult is ResponseWriteResult
                ? writeResult
                : await writeResult;

            _responseSent = true;
            _unflushedBytes += bytesWritten;

            if (!keepAlive) {
              await socket.close();
              _destroy();
              return;
            }

            _parser.reset();
            if (!bodyDone.isCompleted) {
              if (_bodyController != null && !_bodyController!.hasListener) {
                _forceClose = true;
              } else {
                await bodyDone.future;
              }
            }
            if (_isShuttingDown || _forceClose || _clientClosed) {
              await socket.close();
              _destroy();
              return;
            }
            if (_unflushedBytes >= _flushThreshold) {
              _unflushedBytes = 0;
              await socket.flush();
            }
            if (!_readyForNextRequest.isCompleted) {
              _state = .idle;
              if (_isShuttingDown) {
                await socket.close();
                _destroy();
                return;
              }
              _readyForNextRequest.complete();
              _startIdleTimer();
            }
          } finally {
            _cancelWriteTimer();
          }
        } on SocketException catch (error) {
          _responseSent = true;
          if (!_isDestroyed) {
            _logger?.debug(
              'client disconnected during response transmission',
              attrs: [
                .error(error),
                .string('remote_address', remoteAddress.address),
                .int('remote_port', remotePort),
              ],
            );
            _destroy();
          }
          return;
        } finally {
          cancelReqCtx();
        }
      }
    } on HttpParserException catch (error) {
      if (!_isDestroyed) {
        _logger?.debug(
          'http parser error',
          attrs: [
            .error(error),
            .string('remote_address', remoteAddress.address),
            .int('remote_port', remotePort),
          ],
        );
        _sendErrorAndClose(.badRequest);
      }
    } on BodyControllerException catch (error) {
      if (!_isDestroyed) {
        _logger?.debug(
          'http body parser error',
          attrs: [
            .error(error),
            .string('remote_address', remoteAddress.address),
            .int('remote_port', remotePort),
          ],
        );
        _sendErrorAndClose(.badRequest);
      }
    } catch (error, stackTrace) {
      if (!_isDestroyed) {
        _logger?.error(
          'error in handler',
          attrs: [
            .error(error),
            .stackTrace(stackTrace),
            .string('remote_address', remoteAddress.address),
            .int('remote_port', remotePort),
          ],
        );

        if (!_responseSent) {
          _sendErrorAndClose(.internalServerError);
        } else {
          _destroy();
        }
      }
    }
  }

  void _destroy() {
    if (_state == .closed) return;
    _state = .closed;

    _cancelIdleTimer();
    _cancelHeaderTimer();
    _cancelBodyTimer();
    _cancelWriteTimer();
    _currentRequestCancel?.call();
    _subscription?.cancel();
    socket.destroy();
    _bodyController?.close();
    _upgradeController?.close();
    if (!_readyForNextRequest.isCompleted) {
      _readyForNextRequest.complete();
    }
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }
}

class ConnectionInfo {
  const ConnectionInfo({
    required this.remoteAddress,
    required this.remotePort,
    required this.localPort,
  });

  final InternetAddress remoteAddress;
  final int remotePort;
  final int localPort;

  @override
  String toString() => '$remoteAddress:$remotePort -> :$localPort';
}

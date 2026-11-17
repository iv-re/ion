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

/// How long the server waits for an unread request body to arrive after the
/// handler responded, before giving up on keep-alive.
const Duration _maxUnreadBodyWait = Duration(seconds: 5);

/// How long the server keeps reading (and dropping) incoming data after
/// closing its write side with request body bytes still in flight, so the
/// client receives the response instead of a TCP reset.
const Duration _lingerTimeout = Duration(seconds: 2);

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

  final _httpDoneCompleter = Completer<void>();

  /// Completes when the connection stops serving HTTP: it is closed, or it
  /// was upgraded and now belongs to the upgrade handler.
  Future<void> get httpDone => _httpDoneCompleter.future;

  var _isShuttingDown = false;
  var _forceClose = false;
  bool get _isDestroyed => _state == .closed;
  var _clientClosed = false;
  var _responseSent = false;
  var _unflushedBytes = 0;
  var _canSend100Continue = false;
  var _isLingering = false;
  Timer? _lingerTimer;
  Completer<bool>? _unreadBodyWait;

  /// Completed when the current body runs out of its unread budget; armed
  /// anew by each wait, so an earlier overflow is not seen as a new one.
  Completer<void>? _unreadLimitSignal;

  void _onUnreadLimit() {
    final signal = _unreadLimitSignal;
    _unreadLimitSignal = null;
    signal?.complete();
  }

  void start() {
    _startIdleTimer();
    _subscription = socket.listen(
      _onData,
      onDone: () {
        if (_isLingering) {
          _destroy();
        } else if (_upgradeController != null) {
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
        if (_upgradeController case final upgraded?) {
          // cancelOnError: there will be no onDone.
          upgraded
            ..addError(error)
            ..close();
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
      _bodyTimer = Timer(_readBodyTimeout, _onBodyTimeout);
    }
  }

  void _onBodyTimeout() {
    final wait = _unreadBodyWait;
    if (wait != null && !wait.isCompleted) {
      // The handler already responded; send the response with
      // `Connection: close` instead of dropping it.
      wait.complete(false);
    } else {
      _destroy();
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

  /// Decides, before the response is written, whether the connection can stay
  /// alive given a request body the handler did not finish reading.
  ///
  /// A body the handler never listened to is read to the end and dropped if
  /// it fits into the unread buffer. Otherwise keep-alive is not possible,
  /// because the rest of the body would have to be read from the socket.
  Future<bool> _settleUnreadBody(Completer<void> bodyDone) async {
    final controller = _bodyController;
    // A listener that is still reading is awaited after the response is
    // written: the response body may depend on the request body.
    if (bodyDone.isCompleted || controller == null || controller.isReading) {
      return true;
    }
    if (_canSend100Continue) {
      // The client waits for 100 Continue before sending the body.
      _canSend100Continue = false;
      return false;
    }
    if (controller.isPausedUnread || controller.exceedsUnreadBuffer) {
      return false;
    }

    final wait = _unreadBodyWait = Completer<bool>();
    void complete(bool canKeepAlive) {
      if (!wait.isCompleted) wait.complete(canKeepAlive);
    }

    unawaited(bodyDone.future.then((_) => complete(!_forceClose)));
    final unreadLimit = _unreadLimitSignal = Completer<void>();
    unawaited(unreadLimit.future.then((_) => complete(false)));
    final timer = Timer(_maxUnreadBodyWait, () => complete(false));
    try {
      return await wait.future;
    } finally {
      timer.cancel();
      _unreadBodyWait = null;
      _unreadLimitSignal = null;
    }
  }

  /// Waits for the rest of a body after the response head was written.
  ///
  /// Returns `false` when the handler stopped reading and more than the
  /// unread budget is still coming: the connection then has to be closed.
  Future<bool> _finishBodyAfterResponse(Completer<void> bodyDone) async {
    if (bodyDone.isCompleted) return true;
    if (_bodyController?.isPausedUnread ?? false) return false;
    final unreadLimit = _unreadLimitSignal = Completer<void>();
    try {
      return await Future.any([
        bodyDone.future.then((_) => true),
        unreadLimit.future.then((_) => false),
      ]);
    } finally {
      _unreadLimitSignal = null;
    }
  }

  /// Closes the write side and keeps dropping incoming data for a while, so
  /// unread request bytes do not make the OS reset the connection before the
  /// client has read the response.
  Future<void> _lingeringClose() async {
    _isLingering = true;
    _cancelBodyTimer();
    _lingerTimer = Timer(_lingerTimeout, _destroy);
    // The subscription may be paused several times over (unread body
    // buffer, a paused body listener); undo all of them.
    final subscription = _subscription;
    for (var i = 0; i < 8 && (subscription?.isPaused ?? false); i++) {
      subscription!.resume();
    }
    await socket.close();
  }

  /// The connection was upgraded (WebSocket) and no longer serves HTTP.
  bool get isUpgraded => _state == .upgraded;

  /// Closes the connection immediately, aborting any request in progress.
  void destroy() => _destroy();

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
      // The rest of the rejected request may still be arriving; a lingering
      // close keeps it from resetting the connection before the client reads
      // the error.
      unawaited(_lingeringClose().catchError((Object _) => _destroy()));
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
    if (_isLingering) return;
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
            onUnreadLimit: _onUnreadLimit,
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
            onUnreadLimit: _onUnreadLimit,
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

          var keepAlive = request.keepAlive && !_forceClose && !_isShuttingDown;
          if (keepAlive && response.onUpgrade == null) {
            keepAlive = await _settleUnreadBody(bodyDone);
            if (_isDestroyed) return;
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
              if (!_httpDoneCompleter.isCompleted) {
                _httpDoneCompleter.complete();
              }
              _cancelIdleTimer();
              _cancelHeaderTimer();
              _cancelBodyTimer();
              _cancelWriteTimer();
              await socket.flush();
              // A paused reader pauses the socket. The connection lives until
              // the upgraded side closes the socket (or [destroy]).
              _upgradeController = StreamController<Uint8List>(
                sync: true,
                onPause: () => _subscription?.pause(),
                onResume: () => _subscription?.resume(),
              );
              unawaited(
                socket.done
                    .then<void>((_) {}, onError: (Object _) {})
                    .whenComplete(_destroy),
              );
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
              version: request.version,
              keepAlive: keepAlive,
              status: response.status.value,
              headers: response.headers,
              body: response.body,
            );
            final (
              bytesWritten,
              wroteKeepAlive,
            ) = writeResult is ResponseWriteResult
                ? writeResult
                : await writeResult;

            _responseSent = true;
            _unflushedBytes += bytesWritten;

            if (!wroteKeepAlive) {
              if (bodyDone.isCompleted) {
                await socket.close();
                _destroy();
              } else {
                await _lingeringClose();
              }
              return;
            }

            _parser.reset();
            // A handler still reading the body is awaited. One that stopped
            // reading after the head was sent can only be drained up to the
            // unread budget; past it the connection is closed, as Go does.
            if (!await _finishBodyAfterResponse(bodyDone)) {
              _forceClose = true;
            }
            if (_isShuttingDown || _forceClose || _clientClosed) {
              if (bodyDone.isCompleted) {
                await socket.close();
                _destroy();
              } else {
                await _lingeringClose();
              }
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
        } on ResponseBodyException catch (error) {
          // The head is already on the wire: abort instead of writing a 500
          // into the middle of the body.
          _responseSent = true;
          if (!_isDestroyed) {
            _logger?.error(
              'error in response body',
              attrs: [
                .error(error.error),
                .stackTrace(error.stackTrace),
                .string('remote_address', remoteAddress.address),
                .int('remote_port', remotePort),
              ],
            );
            _destroy();
          }
          return;
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
        _sendErrorAndClose(error.status);
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
    _lingerTimer?.cancel();
    _lingerTimer = null;
    _currentRequestCancel?.call();
    _subscription?.cancel();
    socket.destroy();
    _bodyController?.close();
    _upgradeController?.close();
    if (!_readyForNextRequest.isCompleted) {
      _readyForNextRequest.complete();
    }
    if (!_httpDoneCompleter.isCompleted) {
      _httpDoneCompleter.complete();
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

import 'dart:async';
import 'dart:io';

import 'package:ion_web/src/handler.dart';
import 'package:ion_web/src/http/http.dart';
import 'package:ion_web/src/http_response_writer.dart';
import 'package:ion_web/src/server_socket.dart';
import 'package:sl/sl.dart';

class IonServer {
  IonServer._(this._serverSocket);

  final ServerSocketAdapter _serverSocket;
  final Set<HttpConnection> _connections = {};

  /// No new connections are accepted (set by [shutdown] or [close]).
  bool _isClosing = false;

  /// [close] was called.
  bool _isClosed = false;

  InternetAddress get address => _serverSocket.address;
  int get port => _serverSocket.port;

  /// Starts serving [handler] on [address] and [port].
  ///
  /// With [securityContext] the server terminates TLS itself. The TLS
  /// handshake runs inside `dart:io` and cannot be timed out or aborted: a
  /// client that never finishes it holds a socket that is not covered by the
  /// timeouts, is not counted in [maxConnections] and is not closed by
  /// [close]. For a server exposed to the internet, terminate TLS in a proxy
  /// or load balancer instead.
  static Future<IonServer> serve(
    Handler handler, {
    required InternetAddress address,
    required int port,
    SecurityContext? securityContext,
    int backlog = 0,
    bool shared = false,
    int? maxConnections,
    Logger? logger,
    Duration? readHeaderTimeout,
    Duration? readBodyTimeout,
    Duration? writeTimeout,
    Duration? idleTimeout,
    int maxHeaderSize = 64 * 1024,
    int maxHeaderCount = 500,
  }) async {
    final serverSocket = await ServerSocketAdapter.bind(
      address,
      port,
      securityContext: securityContext,
      backlog: backlog,
      shared: shared,
    );

    final server = IonServer._(serverSocket);
    HttpResponseWriter.retainDateCache();

    serverSocket.connections.listen(
      (socket) {
        if (server._isClosing ||
            (maxConnections != null &&
                server._connections.length >= maxConnections)) {
          socket.destroy();
          return;
        }

        InternetAddress? remoteAddress;
        int? remotePort;

        try {
          remoteAddress = socket.remoteAddress;
          remotePort = socket.remotePort;

          if (socket.address.type != .unix) {
            socket.setOption(.tcpNoDelay, true);
          }

          final connection = HttpConnection(
            socket,
            handler: handler,
            logger: logger,
            readHeaderTimeout: readHeaderTimeout,
            readBodyTimeout: readBodyTimeout,
            writeTimeout: writeTimeout,
            idleTimeout: idleTimeout,
            maxHeaderSize: maxHeaderSize,
            maxHeaderCount: maxHeaderCount,
          );

          server._connections.add(connection);
          unawaited(
            connection.done.whenComplete(() {
              server._connections.remove(connection);
            }),
          );

          connection.start();
        } catch (error, stackTrace) {
          logger?.error(
            'error handling connection accept',
            attrs: [
              .error(error),
              .stackTrace(stackTrace),
              if (remoteAddress != null)
                .string('remote_address', remoteAddress.toString()),
              if (remotePort != null) .int('remote_port', remotePort),
            ],
          );

          try {
            socket.destroy();
          } catch (_) {}
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        logger?.error(
          'error accepting connection',
          attrs: [.error(error), .stackTrace(stackTrace)],
        );
      },
    );

    return server;
  }

  /// Stops accepting connections, lets in-flight requests finish and closes
  /// idle connections. After [timeout], remaining connections are destroyed.
  ///
  /// [close] may be called meanwhile to destroy them right away.
  Future<void> shutdown({Duration? timeout}) async {
    if (_isClosing) return;
    await _stopAccepting();

    for (final connection in _connections.toList()) {
      connection.shutdown();
    }

    final allClosed = Future.wait([for (final c in _connections) c.done]);
    if (timeout == null) {
      await allClosed;
      return;
    }
    try {
      await allClosed.timeout(timeout);
    } on TimeoutException {
      _destroyConnections();
    }
  }

  /// Stops accepting connections and destroys open ones immediately,
  /// including during a [shutdown].
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    await _stopAccepting();
    _destroyConnections();
  }

  Future<void> _stopAccepting() async {
    if (_isClosing) return;
    _isClosing = true;
    HttpResponseWriter.releaseDateCache();
    await _serverSocket.close();
  }

  void _destroyConnections() {
    for (final connection in _connections.toList()) {
      connection.destroy();
    }
  }
}

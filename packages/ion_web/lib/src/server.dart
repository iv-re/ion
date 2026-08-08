import 'dart:async';
import 'dart:io';

import 'package:ion_web/src/handler.dart';
import 'package:ion_web/src/http/http.dart';
import 'package:ion_web/src/server_socket.dart';
import 'package:sl/sl.dart';

class IonServer {
  IonServer._(this._serverSocket);

  final ServerSocketAdapter _serverSocket;
  final Set<HttpConnection> _connections = {};
  bool _isClosing = false;

  InternetAddress get address => _serverSocket.address;
  int get port => _serverSocket.port;

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

    serverSocket.listen(
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

  Future<void> shutdown({Duration? timeout}) async {
    if (_isClosing) return;
    _isClosing = true;

    await _serverSocket.close();

    if (_connections.isEmpty) return;

    final connectionsSnapshot = _connections.toList();
    for (final connection in connectionsSnapshot) {
      connection.shutdown();
    }

    final allClosed = Future.wait(
      _connections.map((c) => c.done).toList(),
    );

    if (timeout != null) {
      try {
        await allClosed.timeout(timeout);
      } on TimeoutException {
        for (final connection in _connections.toList()) {
          try {
            connection.socket.destroy();
          } catch (_) {}
        }
      }
    } else {
      await allClosed;
    }
  }

  Future<void> close() async {
    if (_isClosing) return;
    _isClosing = true;

    await _serverSocket.close();

    for (final connection in _connections.toList()) {
      try {
        connection.socket.destroy();
      } catch (_) {}
    }
    _connections.clear();
  }
}

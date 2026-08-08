import 'dart:async';
import 'dart:io';

/// Unified adapter interface for underlying TCP and TLS server sockets.
abstract interface class ServerSocketAdapter {
  InternetAddress get address;
  int get port;

  StreamSubscription<Socket> listen(
    void Function(Socket socket) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  });

  Future<void> close();

  /// Binds a [ServerSocketAdapter] to the given [address] and [port].
  ///
  /// If [securityContext] is provided, a TLS ([SecureServerSocket]) is bound;
  /// otherwise a standard TCP ([ServerSocket]) is bound.
  static Future<ServerSocketAdapter> bind(
    InternetAddress address,
    int port, {
    SecurityContext? securityContext,
    int backlog = 0,
    bool shared = false,
  }) async {
    if (securityContext != null) {
      final socket = await SecureServerSocket.bind(
        address,
        port,
        securityContext,
        backlog: backlog,
        shared: shared,
      );
      return _TlsServerSocketAdapter(socket);
    } else {
      final socket = await ServerSocket.bind(
        address,
        port,
        backlog: backlog,
        shared: shared,
      );
      return _TcpServerSocketAdapter(socket);
    }
  }
}

class _TcpServerSocketAdapter implements ServerSocketAdapter {
  _TcpServerSocketAdapter(this._socket);

  final ServerSocket _socket;

  @override
  InternetAddress get address => _socket.address;

  @override
  int get port => _socket.port;

  @override
  StreamSubscription<Socket> listen(
    void Function(Socket socket) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _socket.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Future<void> close() => _socket.close();
}

class _TlsServerSocketAdapter implements ServerSocketAdapter {
  _TlsServerSocketAdapter(this._socket);

  final SecureServerSocket _socket;

  @override
  InternetAddress get address => _socket.address;

  @override
  int get port => _socket.port;

  @override
  StreamSubscription<Socket> listen(
    void Function(Socket socket) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _socket.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Future<void> close() => _socket.close();
}

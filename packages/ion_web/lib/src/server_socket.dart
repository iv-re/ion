import 'dart:async';
import 'dart:io';

/// A bound TCP ([ServerSocket]) or TLS ([SecureServerSocket]) server socket.
///
/// Both are a `Stream<Socket>` with an address, a port and `close`; this only
/// gives them one type.
final class ServerSocketAdapter {
  ServerSocketAdapter._(this.connections, this.address, this.port, this._close);

  /// Binds to [address] and [port]: TLS when [securityContext] is given,
  /// plain TCP otherwise.
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
      return ._(socket, socket.address, socket.port, socket.close);
    }
    final socket = await ServerSocket.bind(
      address,
      port,
      backlog: backlog,
      shared: shared,
    );
    return ._(socket, socket.address, socket.port, socket.close);
  }

  /// Accepted client connections.
  final Stream<Socket> connections;
  final InternetAddress address;
  final int port;
  final Future<void> Function() _close;

  Future<void> close() => _close();
}

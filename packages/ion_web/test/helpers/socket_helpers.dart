import 'dart:async';
import 'dart:io';

import 'package:ion_web/ion_web.dart';
import 'package:ion_web/src/http/http.dart';

import 'bytes.dart';

/// Sends a raw HTTP request text over a TCP socket and collects
/// raw response text.
Future<String> sendRawHttpRequest(
  int port,
  String requestText, {
  InternetAddress? host,
}) async {
  final client = await Socket.connect(
    host ?? InternetAddress.loopbackIPv4,
    port,
  );
  client.add(stringToBytes(requestText));

  final responseBytes = <int>[];
  await client.forEach(responseBytes.addAll);
  await client.close();

  return bytesToString(Uint8List.fromList(responseBytes));
}

/// Helper that attaches an [HttpConnection] handler to a [serverSocket],
/// sends a raw HTTP request, and returns the raw HTTP response string.
Future<String> sendConnectionRequest(
  ServerSocket serverSocket,
  String requestText, {
  required FutureOr<Response> Function(Request) handler,
  Duration? readHeaderTimeout,
  Duration? readBodyTimeout,
  Duration? writeTimeout,
}) async {
  serverSocket.listen((socket) {
    final connection = HttpConnection(
      socket,
      handler: handler,
      readHeaderTimeout: readHeaderTimeout,
      readBodyTimeout: readBodyTimeout,
      writeTimeout: writeTimeout,
    );
    connection.start();
  });

  return sendRawHttpRequest(serverSocket.port, requestText);
}

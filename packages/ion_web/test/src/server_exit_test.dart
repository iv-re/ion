import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:ion_web/ion_web.dart';
import 'package:test/test.dart';

/// Serves one request, closes the server and returns, leaving nothing that
/// should keep the isolate alive.
Future<void> _serveOneRequest(SendPort done) async {
  final server = await IonServer.serve(
    (request) => Response.text('ok'),
    address: InternetAddress.loopbackIPv4,
    port: 0,
  );
  final socket = await Socket.connect(
    InternetAddress.loopbackIPv4,
    server.port,
  );
  socket.add(
    ascii.encode(
      'GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
    ),
  );
  final response = await socket
      .cast<List<int>>()
      .transform(latin1.decoder)
      .join();
  socket.destroy();
  await server.close();
  done.send(response.startsWith('HTTP/1.1 200'));
}

void main() {
  test('the isolate exits once the server is closed', () async {
    final done = ReceivePort();
    final exited = ReceivePort();
    addTearDown(done.close);
    addTearDown(exited.close);

    await Isolate.spawn(
      _serveOneRequest,
      done.sendPort,
      onExit: exited.sendPort,
    );

    expect(await done.first, isTrue);
    await expectLater(
      exited.first.timeout(const Duration(seconds: 5)),
      completes,
    );
  });
}

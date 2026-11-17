import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ion_web/ion_web.dart';
import 'package:test/test.dart';

/// Response bytes must stay intact while a slow client's socket still holds
/// them, even when other responses are written in the meantime.
void main() {
  test('a stalled client receives its own response headers', () async {
    final body = Uint8List(64 * 1024);
    final server = await IonServer.serve(
      (request) => Response.bytes(
        body,
        headers: [.server(request.uri.queryParameters['seq']!)],
      ),
      address: InternetAddress.loopbackIPv4,
      port: 0,
    );
    addTearDown(server.close);

    // Client A pipelines requests and does not read, so the server's socket
    // write buffer fills up and later response heads stay queued.
    final a = await Socket.connect(InternetAddress.loopbackIPv4, server.port);
    addTearDown(a.destroy);
    final received = <int>[];
    final subscription = a.listen(received.addAll)..pause();
    addTearDown(subscription.cancel);
    const count = 40;
    final requests = StringBuffer();
    for (var i = 0; i < count; i++) {
      requests.write(
        'GET /?seq=A${i.toString().padLeft(3, '0')} HTTP/1.1\r\n'
        'Host: localhost\r\n\r\n',
      );
    }
    a.add(ascii.encode(requests.toString()));
    await Future<void>.delayed(const Duration(milliseconds: 300));

    // Client B is served while A is stalled.
    for (var i = 0; i < 5; i++) {
      final b = await Socket.connect(InternetAddress.loopbackIPv4, server.port);
      b.add(
        ascii.encode(
          'GET /?seq=BBB$i HTTP/1.1\r\n'
          'Host: localhost\r\n'
          'Connection: close\r\n\r\n',
        ),
      );
      await b.drain<void>();
    }

    subscription.resume();
    final expectedLength = count * body.length;
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (received.length < expectedLength &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    final seqs = RegExp(r'[Ss]erver: (\w+)')
        .allMatches(latin1.decode(received))
        .map((m) => m[1])
        .toList();
    expect(seqs, [
      for (var i = 0; i < count; i++) 'A${i.toString().padLeft(3, '0')}',
    ]);
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ion_web/ion_web.dart';
import 'package:ion_web/src/http/http.dart';
import 'package:test/test.dart';

/// Tests for request bodies the handler has not started reading (yet),
/// run over real loopback sockets.
void main() {
  late ServerSocket serverSocket;
  late List<HttpConnection> connections;

  Future<void> serve(
    FutureOr<Response> Function(Request) handler, {
    Duration? readBodyTimeout,
  }) async {
    serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    serverSocket.listen((socket) {
      socket.setOption(SocketOption.tcpNoDelay, true);
      final connection = HttpConnection(
        socket,
        handler: handler,
        readBodyTimeout: readBodyTimeout,
      );
      connections.add(connection);
      connection.start();
    });
  }

  setUp(() => connections = []);

  tearDown(() async {
    await serverSocket.close();
    for (final connection in connections) {
      connection.socket.destroy();
    }
  });

  Future<_RawClient> connect() async => _RawClient(
    await Socket.connect(InternetAddress.loopbackIPv4, serverSocket.port),
  );

  Future<Uint8List> readAll(Request request) async {
    final builder = BytesBuilder(copy: false);
    await request.forEach(builder.add);
    return builder.takeBytes();
  }

  group('body read after a delay', () {
    const delay = Duration(milliseconds: 200);
    final body = _pattern(8 * 1024 * 1024);

    test('fixed-length 8 MB body arrives byte for byte', () async {
      final received = Completer<Uint8List>();
      await serve((request) async {
        await Future<void>.delayed(delay);
        received.complete(await readAll(request));
        return Response.text('ok');
      });

      final client = await connect();
      client.socket
        ..add(
          ascii.encode(
            'POST /upload HTTP/1.1\r\n'
            'Host: localhost\r\n'
            'Content-Length: ${body.length}\r\n'
            '\r\n',
          ),
        )
        ..add(body);

      final response = await client.readResponse();
      expect(response.status, 200);
      final bytes = await received.future;
      expect(bytes.length, body.length);
      expect(bytes, orderedEquals(body));
      await client.close();
    });

    test('chunked 8 MB body arrives byte for byte', () async {
      final received = Completer<Uint8List>();
      await serve((request) async {
        await Future<void>.delayed(delay);
        received.complete(await readAll(request));
        return Response.text('ok');
      });

      final client = await connect();
      client.socket.add(
        ascii.encode(
          'POST /upload HTTP/1.1\r\n'
          'Host: localhost\r\n'
          'Transfer-Encoding: chunked\r\n'
          '\r\n',
        ),
      );
      const chunkSize = 64 * 1024;
      for (var offset = 0; offset < body.length; offset += chunkSize) {
        final chunk = Uint8List.sublistView(body, offset, offset + chunkSize);
        client.socket
          ..add(ascii.encode('${chunk.length.toRadixString(16)}\r\n'))
          ..add(chunk)
          ..add(ascii.encode('\r\n'));
      }
      client.socket.add(ascii.encode('0\r\n\r\n'));

      final response = await client.readResponse();
      expect(response.status, 200);
      final bytes = await received.future;
      expect(bytes.length, body.length);
      expect(bytes, orderedEquals(body));
      await client.close();
    });
  });

  group('response without reading the body', () {
    Response unauthorized(Request request) =>
        Response.text('denied', status: .unauthorized);

    test('small late body keeps the connection alive', () async {
      await serve((request) {
        if (request.method == .post) return unauthorized(request);
        return Response.text('second');
      });

      final client = await connect();
      client.socket.add(
        ascii.encode(
          'POST /login HTTP/1.1\r\n'
          'Host: localhost\r\n'
          'Content-Length: 5\r\n'
          '\r\n',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      client.socket.add(ascii.encode('hello'));

      final first = await client.readResponse();
      expect(first.status, 401);
      expect(first.headers['connection'], isNot('close'));

      client.socket.add(
        ascii.encode('GET /next HTTP/1.1\r\nHost: localhost\r\n\r\n'),
      );
      final second = await client.readResponse();
      expect(second.status, 200);
      expect(second.body, 'second');
      await client.close();
    });

    test('8 MB fixed-length body: Connection: close, socket closed', () async {
      await serve(unauthorized);
      final body = _pattern(8 * 1024 * 1024);

      final client = await connect();
      client.socket
        ..add(
          ascii.encode(
            'POST /upload HTTP/1.1\r\n'
            'Host: localhost\r\n'
            'Content-Length: ${body.length}\r\n'
            '\r\n',
          ),
        )
        ..add(body);

      final response = await client.readResponse();
      expect(response.status, 401);
      expect(response.body, 'denied');
      expect(response.headers['connection'], 'close');
      await client.closed.timeout(const Duration(seconds: 5));
    });

    test('large chunked body: Connection: close without waiting', () async {
      await serve(unauthorized);

      final client = await connect();
      client.socket.add(
        ascii.encode(
          'POST /upload HTTP/1.1\r\n'
          'Host: localhost\r\n'
          'Transfer-Encoding: chunked\r\n'
          '\r\n',
        ),
      );
      final chunk = _pattern(64 * 1024);
      for (var i = 0; i < 64; i++) {
        client.socket
          ..add(ascii.encode('${chunk.length.toRadixString(16)}\r\n'))
          ..add(chunk)
          ..add(ascii.encode('\r\n'));
      }

      final stopwatch = Stopwatch()..start();
      final response = await client.readResponse();
      expect(response.status, 401);
      expect(response.headers['connection'], 'close');
      // Decided by the unread buffer filling up, not by a timeout.
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
      await client.closed.timeout(const Duration(seconds: 5));
    });

    test('Expect: 100-continue: no 100 Continue, Connection: close', () async {
      await serve(unauthorized);

      final client = await connect();
      client.socket.add(
        ascii.encode(
          'POST /upload HTTP/1.1\r\n'
          'Host: localhost\r\n'
          'Content-Length: 10\r\n'
          'Expect: 100-continue\r\n'
          '\r\n',
        ),
      );

      final response = await client.readResponse();
      expect(response.status, 401);
      expect(response.headers['connection'], 'close');
      await client.closed.timeout(const Duration(seconds: 5));
      expect(client.rawText, isNot(contains('100 Continue')));
    });

    test('body never sent, readBodyTimeout hit: response still sent '
        'with Connection: close', () async {
      await serve(
        unauthorized,
        readBodyTimeout: const Duration(milliseconds: 300),
      );

      final client = await connect();
      client.socket.add(
        ascii.encode(
          'POST /upload HTTP/1.1\r\n'
          'Host: localhost\r\n'
          'Content-Length: 10\r\n'
          '\r\n',
        ),
      );

      final response = await client.readResponse();
      expect(response.status, 401);
      expect(response.headers['connection'], 'close');
      await client.closed.timeout(const Duration(seconds: 5));
    });

    test('body never sent, no readBodyTimeout: waiting is bounded', () async {
      await serve(unauthorized);

      final client = await connect();
      client.socket.add(
        ascii.encode(
          'POST /upload HTTP/1.1\r\n'
          'Host: localhost\r\n'
          'Content-Length: 10\r\n'
          '\r\n',
        ),
      );

      final response = await client.readResponse().timeout(
        const Duration(seconds: 8),
      );
      expect(response.status, 401);
      expect(response.headers['connection'], 'close');
      await client.closed.timeout(const Duration(seconds: 5));
    });
  });

  group('keep-alive with a body listener', () {
    test('handler reads the body, two requests in a row', () async {
      final bodies = <String>[];
      await serve((request) async {
        bodies.add(utf8.decode(await readAll(request)));
        return Response.text('got ${bodies.length}');
      });

      final client = await connect();
      for (final text in ['first', 'second']) {
        client.socket.add(
          ascii.encode(
            'POST /echo HTTP/1.1\r\n'
            'Host: localhost\r\n'
            'Content-Length: ${text.length}\r\n'
            '\r\n'
            '$text',
          ),
        );
        final response = await client.readResponse();
        expect(response.status, 200);
        expect(response.headers['connection'], isNot('close'));
      }
      expect(bodies, ['first', 'second']);
      await client.close();
    });

    test('handler cancels the body mid-way, connection stays usable', () async {
      await serve((request) async {
        if (request.method == .post) {
          await request.first;
          return Response.text('partial');
        }
        return Response.text('second');
      });

      final body = _pattern(1024 * 1024);
      final client = await connect();
      client.socket
        ..add(
          ascii.encode(
            'POST /upload HTTP/1.1\r\n'
            'Host: localhost\r\n'
            'Content-Length: ${body.length}\r\n'
            '\r\n',
          ),
        )
        ..add(body);

      final first = await client.readResponse();
      expect(first.status, 200);
      expect(first.headers['connection'], isNot('close'));

      client.socket.add(
        ascii.encode('GET /next HTTP/1.1\r\nHost: localhost\r\n\r\n'),
      );
      final second = await client.readResponse().timeout(
        const Duration(seconds: 5),
      );
      expect(second.body, 'second');
      await client.close();
    });
  });
}

Uint8List _pattern(int length) {
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = i % 251;
  }
  return bytes;
}

class _RawResponse {
  _RawResponse(this.status, this.headers, this.body);

  final int status;
  final Map<String, String> headers;
  final String body;
}

/// A raw TCP client that reads HTTP responses as they arrive, while the
/// request body may still be in flight.
class _RawClient {
  _RawClient(this.socket) {
    socket.listen(
      (data) {
        _buffer.addAll(data);
        _all.addAll(data);
        _notify();
      },
      onDone: _onClosed,
      onError: (Object _) => _onClosed(),
      cancelOnError: true,
    );
    // Writes of an unread body fail once the server closes; that is expected.
    socket.done.catchError((Object _) {});
  }

  final Socket socket;
  final _buffer = <int>[];
  final _all = <int>[];
  final _closed = Completer<void>();
  Completer<void>? _waiter;

  Future<void> get closed => _closed.future;
  String get rawText => latin1.decode(_all);

  void _notify() {
    _waiter?.complete();
    _waiter = null;
  }

  void _onClosed() {
    if (!_closed.isCompleted) _closed.complete();
    _notify();
  }

  Future<void> _more() {
    if (_closed.isCompleted) {
      throw StateError('connection closed: ${latin1.decode(_buffer)}');
    }
    return (_waiter ??= Completer<void>()).future;
  }

  Future<_RawResponse> readResponse() async {
    while (true) {
      final response = await _readOne();
      if (response.status >= 200) return response;
    }
  }

  Future<_RawResponse> _readOne() async {
    int headerEnd;
    while ((headerEnd = _indexOfHeaderEnd()) < 0) {
      await _more();
    }
    final lines = latin1.decode(_buffer.sublist(0, headerEnd)).split('\r\n');
    final status = int.parse(lines.first.split(' ')[1]);
    final headers = <String, String>{
      for (final line in lines.skip(1))
        line.substring(0, line.indexOf(':')).toLowerCase(): line
            .substring(line.indexOf(':') + 1)
            .trim(),
    };
    _buffer.removeRange(0, headerEnd + 4);
    final length = int.parse(headers['content-length'] ?? '0');
    while (_buffer.length < length) {
      await _more();
    }
    final body = utf8.decode(_buffer.sublist(0, length));
    _buffer.removeRange(0, length);
    return _RawResponse(status, headers, body);
  }

  int _indexOfHeaderEnd() {
    for (var i = 0; i + 3 < _buffer.length; i++) {
      if (_buffer[i] == 13 &&
          _buffer[i + 1] == 10 &&
          _buffer[i + 2] == 13 &&
          _buffer[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }

  Future<void> close() async {
    socket.destroy();
  }
}

import 'dart:async';
import 'dart:io';

import 'package:ion_web/ion_web.dart';
import 'package:ion_web/src/http/http.dart';
import 'package:test/test.dart';

import '../helpers/helpers.dart';

void main() {
  group('WebSocket upgrade', () {
    late ServerSocket serverSocket;

    setUp(() async {
      serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    });

    tearDown(() async {
      await serverSocket.close();
    });

    test('WebSocketResponse writes 101 and detaches socket', () async {
      serverSocket.listen((socket) {
        HttpConnection(
          socket,
          handler: (Request request) {
            expect(request.isWebSocketUpgrade, isTrue);

            return Response.websocket((channel) async {
              channel.sink.add('hello from ws');
              await channel.sink.close();
            });
          },
        ).start();
      });

      final ws = await WebSocket.connect(
        'ws://localhost:${serverSocket.port}/ws',
      );

      final messages = <String>[];
      final done = Completer<void>();
      ws.listen(
        (message) => messages.add(message as String),
        onDone: done.complete,
      );

      await done.future;
      await ws.close();

      expect(messages, ['hello from ws']);
    });

    test('Request.isWebSocketUpgrade returns false for non-upgrade', () {
      final request = TestRequestBuilder.get().build();

      expect(request.isWebSocketUpgrade, isFalse);
    });

    test('Request.isWebSocketUpgrade returns false for POST upgrade', () {
      final request = TestRequestBuilder.post().headers([
        const .connectionUpgrade(),
        const .upgradeWebsocket(),
      ]).build();

      expect(request.isWebSocketUpgrade, isFalse);
    });

    test('ConnectionHeader.upgrade is parsed correctly', () {
      final headers = TypedHeaders.fromList([
        const .connectionUpgrade(),
        const .upgradeWebsocket(),
      ]);

      expect(headers.connection?.isUpgrade, isTrue);
      expect(headers.upgrade, isNotNull);
      expect(headers.upgrade!.protocols, contains('websocket'));
    });

    test('Response.websocket returns 400 without Sec-WebSocket-Key', () async {
      final request = TestRequestBuilder.get('/ws').headers([
        const .connectionUpgrade(),
        const .upgradeWebsocket(),
      ]).build();

      final response = Response.websocket((_) {}) as ResolvableResponse;
      final prepared = await response.resolve(request);

      expect(prepared.status, equals(HttpStatusCode.badRequest));
      expect(prepared.onUpgrade, isNull);
    });

    test(
      'Response.websocket returns 400 Bad Request with '
      'Sec-WebSocket-Version: 13 header when version is invalid or missing',
      () async {
        final request = TestRequestBuilder.get('/ws').headers([
          const .connectionUpgrade(),
          const .upgradeWebsocket(),
          const .secWebSocketKey('dGhlIHNhbXBsZSBub25jZQ=='),
          const .secWebSocketVersion(12),
        ]).build();

        final response = Response.websocket((_) {}) as ResolvableResponse;
        final prepared = await response.resolve(request);

        expect(prepared.status, equals(HttpStatusCode.badRequest));
        expect(prepared.onUpgrade, isNull);
        expect(prepared.headers.has<SecWebSocketVersionHeader>(), isTrue);
      },
    );

    test('Response.websocket returns upgrade with valid key', () {
      final response = Response.websocket((_) {});
      expect(response, isA<WebSocketResponse>());
    });

    test('WebSocket subprotocol negotiation and custom headers', () async {
      String? serverNegotiatedProtocol;

      serverSocket.listen((socket) {
        HttpConnection(
          socket,
          handler: (Request request) {
            return Response.websocket(
              (channel) async {
                serverNegotiatedProtocol = channel.protocol;
                channel.sink.add('subprotocol-ack');
                await channel.sink.close();
              },
              protocolSelector: (requested) {
                if (requested.contains('graphql-ws')) {
                  return 'graphql-ws';
                }
                return null;
              },
              headers: [const ServerHeader('CustomValue')],
            );
          },
        ).start();
      });

      final ws = await WebSocket.connect(
        'ws://localhost:${serverSocket.port}/ws',
        protocols: ['graphql-ws', 'wamp'],
      );

      final messages = <String>[];
      final done = Completer<void>();
      ws.listen(
        (message) => messages.add(message as String),
        onDone: done.complete,
      );

      await done.future;

      expect(ws.protocol, 'graphql-ws');
      expect(serverNegotiatedProtocol, 'graphql-ws');
      expect(messages, ['subprotocol-ack']);
      await ws.close();
    });

    test('TypedHeaders and TypedHeader WebSocket extensions', () {
      final headers = TypedHeaders.fromList([
        const .connectionUpgrade(),
        const .upgradeWebsocket(),
        const .secWebSocketKey('dGhlIHNhbXBsZSBub25jZQ=='),
        const .secWebSocketProtocol(['graphql-transport-ws', 'graphql-ws']),
        const .secWebSocketVersionV13(),
      ]);

      expect(headers.secWebSocketKey?.value, 'dGhlIHNhbXBsZSBub25jZQ==');
      expect(
        headers.secWebSocketProtocol?.protocols,
        ['graphql-transport-ws', 'graphql-ws'],
      );
      expect(headers.secWebSocketVersion?.version, 13);

      const upgradeHeader = TypedHeader.upgradeWebsocket();
      expect(upgradeHeader.name, 'Upgrade');
      expect(upgradeHeader.value, 'websocket');

      const acceptHeader = TypedHeader.secWebSocketAccept('acceptKey123');
      expect(acceptHeader.name, 'Sec-WebSocket-Accept');
      expect(acceptHeader.value, 'acceptKey123');

      const protocolHeader = TypedHeader.secWebSocketProtocol(['graphql-ws']);
      expect(protocolHeader.name, 'Sec-WebSocket-Protocol');
      expect(protocolHeader.value, 'graphql-ws');

      const versionHeader = TypedHeader.secWebSocketVersionV13();
      expect(versionHeader.name, 'Sec-WebSocket-Version');
      expect(versionHeader.value, '13');
    });

    test('Response.websocket rejects Cross-Origin request with 403 Forbidden '
        'by default', () async {
      final request = TestRequestBuilder.get('/ws').headers([
        const .connectionUpgrade(),
        const .upgradeWebsocket(),
        const .secWebSocketKey('dGhlIHNhbXBsZSBub25jZQ=='),
        const .secWebSocketVersionV13(),
        const .host('localhost'),
        .origin(.parts('http', 'evil.com')),
      ]).build();

      final response = Response.websocket((_) {}) as ResolvableResponse;
      final prepared = await response.resolve(request);

      expect(prepared.status, equals(HttpStatusCode.forbidden));
      expect(prepared.onUpgrade, isNull);
    });

    test('Response.websocket allows Same-Origin request by default', () async {
      final request = TestRequestBuilder.get('/ws').headers([
        const .connectionUpgrade(),
        const .upgradeWebsocket(),
        const .secWebSocketKey('dGhlIHNhbXBsZSBub25jZQ=='),
        const .secWebSocketVersionV13(),
        const .host('localhost'),
        .origin(.parts('http', 'localhost')),
      ]).build();

      final response = Response.websocket((_) {}) as ResolvableResponse;
      final prepared = await response.resolve(request);

      expect(prepared.status, equals(HttpStatusCode.switchingProtocols));
      expect(prepared.onUpgrade, isNotNull);
      expect(prepared.headers.has<SecWebSocketAcceptHeader>(), isTrue);
    });

    test('Response.websocket respects custom checkOrigin callback', () async {
      final request = TestRequestBuilder.get('/ws').headers([
        const .connectionUpgrade(),
        const .upgradeWebsocket(),
        const .secWebSocketKey('dGhlIHNhbXBsZSBub25jZQ=='),
        const .secWebSocketVersionV13(),
        const .host('localhost'),
        .origin(.parts('http', 'custom-trusted-domain.com')),
      ]).build();

      final response =
          Response.websocket(
                (_) {},
                checkOrigin: (origin) {
                  return origin == 'http://custom-trusted-domain.com';
                },
              )
              as ResolvableResponse;
      final prepared = await response.resolve(request);

      expect(prepared.status, equals(HttpStatusCode.switchingProtocols));
      expect(prepared.onUpgrade, isNotNull);
      expect(prepared.headers.has<SecWebSocketAcceptHeader>(), isTrue);
    });
  });
}

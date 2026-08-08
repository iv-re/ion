import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:stream_channel/stream_channel.dart';
import 'package:stream_web_socket_channel/stream_web_socket_channel.dart';
import 'package:test/test.dart';

void main() {
  group('StreamWebSocketChannel', () {
    late StreamController<List<int>> incomingController;
    late StreamController<List<int>> outgoingController;
    late StreamChannel<List<int>> channel;
    late StreamWebSocketChannel wsChannel;

    setUp(() {
      incomingController = StreamController<List<int>>(sync: true);
      outgoingController = StreamController<List<int>>(sync: true);
      channel = StreamChannel<List<int>>(
        incomingController.stream,
        outgoingController.sink,
      );
      wsChannel = StreamWebSocketChannel(channel);
    });

    tearDown(() {
      incomingController.close();
      outgoingController.close();
    });

    test('parses masked text frame from client correctly', () async {
      final messages = <Object?>[];
      wsChannel.stream.listen(messages.add);

      final clientFrame = _buildFrame(
        opcode: WebSocketOpcode.text,
        payload: utf8.encode('hello'),
      );

      incomingController.add(clientFrame);
      await pumpEventQueue();

      expect(messages, ['hello']);
    });

    test('parses masked binary frame from client correctly', () async {
      final messages = <Object?>[];
      wsChannel.stream.listen(messages.add);

      final clientFrame = _buildFrame(
        opcode: WebSocketOpcode.binary,
        maskKey: [0xAA, 0xBB, 0xCC, 0xDD],
        payload: [1, 2, 3, 4],
      );

      incomingController.add(clientFrame);
      await pumpEventQueue();

      expect(messages.length, 1);
      expect(messages.first, isA<Uint8List>());
      expect(messages.first as Uint8List?, equals([1, 2, 3, 4]));
    });

    test('sends text frame to client unmasked', () async {
      final sentBytes = <List<int>>[];
      outgoingController.stream.listen(sentBytes.add);

      wsChannel.sink.add('world');
      await pumpEventQueue();

      final combined = Uint8List.fromList(sentBytes.expand((b) => b).toList());
      // Header: 0x81 (FIN + Text), 0x05 (Length 5, unmasked)
      expect(combined.sublist(0, 2), equals([0x81, 0x05]));
      expect(utf8.decode(combined.sublist(2)), equals('world'));
    });

    test('handles 16-bit extended payload length (len = 200)', () async {
      final messages = <Object?>[];
      wsChannel.stream.listen(messages.add);

      final payload = List.generate(200, (i) => i % 256);
      final frame = _buildFrame(
        opcode: WebSocketOpcode.binary,
        maskKey: [0x01, 0x02, 0x03, 0x04],
        payload: payload,
      );

      incomingController.add(frame);
      await pumpEventQueue();

      expect(messages.length, 1);
      expect(messages.first as Uint8List?, equals(payload));
    });

    test('automatically responds with Pong on Ping frame', () async {
      final sentBytes = <List<int>>[];
      outgoingController.stream.listen(sentBytes.add);

      final frame = _buildFrame(
        opcode: WebSocketOpcode.ping,
        maskKey: [0x11, 0x22, 0x33, 0x44],
        payload: utf8.encode('ping'),
      );

      incomingController.add(frame);
      await pumpEventQueue();

      final combined = Uint8List.fromList(sentBytes.expand((b) => b).toList());
      // Pong header: 0x8A (FIN + Pong), 0x04 (Length 4, unmasked)
      expect(combined.sublist(0, 2), equals([0x8A, 0x04]));
      expect(utf8.decode(combined.sublist(2)), equals('ping'));
    });

    test('handles incremental byte feeding across frame boundaries', () async {
      final messages = <Object?>[];
      wsChannel.stream.listen(messages.add);

      final frame = _buildFrame(
        opcode: WebSocketOpcode.text,
        payload: utf8.encode('hello'),
      );

      // Feed byte by byte
      for (final byte in frame) {
        incomingController.add([byte]);
      }
      await pumpEventQueue();

      expect(messages, ['hello']);
    });

    test('rejects unmasked frames from client with Close Code 1002', () async {
      final errors = <Object>[];
      wsChannel.stream.listen((_) {}, onError: errors.add);

      final frame = _buildFrame(
        opcode: WebSocketOpcode.text,
        masked: false,
        payload: utf8.encode('hello'),
      );

      incomingController.add(frame);
      await pumpEventQueue();

      expect(wsChannel.closeCode, equals(1002));
    });

    test('rejects non-zero RSV bits with Close Code 1002', () async {
      final errors = <Object>[];
      wsChannel.stream.listen((_) {}, onError: errors.add);

      final frame = _buildFrame(
        opcode: WebSocketOpcode.text,
        rsv: 1,
        payload: utf8.encode('hello'),
      );

      incomingController.add(frame);
      await pumpEventQueue();

      expect(wsChannel.closeCode, equals(1002));
    });

    test('rejects control frame with payload > 125 bytes', () async {
      final errors = <Object>[];
      wsChannel.stream.listen((_) {}, onError: errors.add);

      final frame = _buildFrame(
        opcode: WebSocketOpcode.ping,
        rawPayloadLength: 126,
      );

      incomingController.add(frame);
      expect(wsChannel.closeCode, equals(1002));
    });

    test(
      'server-initiated sink.close sends Close Frame with code and reason',
      () async {
        final sentBytes = <List<int>>[];
        outgoingController.stream.listen(sentBytes.add);

        await wsChannel.sink.close(1000, 'goodbye');
        await pumpEventQueue();

        final combined = Uint8List.fromList(
          sentBytes.expand((b) => b).toList(),
        );
        // Opcode 0x8 (Close), len 9 (2 bytes code + 7 bytes 'goodbye')
        expect(combined.sublist(0, 2), equals([0x88, 0x09]));
        final code = (combined[2] << 8) | combined[3];
        final reason = utf8.decode(combined.sublist(4));
        expect(code, equals(1000));
        expect(reason, equals('goodbye'));
      },
    );

    test(
      'reassembles fragmented text frame across multiple continuation frames',
      () async {
        final messages = <Object?>[];
        wsChannel.stream.listen(messages.add);

        final frame1 = _buildFrame(
          fin: false,
          opcode: WebSocketOpcode.text,
          maskKey: [0x11, 0x22, 0x33, 0x44],
          payload: utf8.encode('hello '),
        );

        final frame2 = _buildFrame(
          opcode: WebSocketOpcode.continuation,
          maskKey: [0x55, 0x66, 0x77, 0x88],
          payload: utf8.encode('world'),
        );

        incomingController.add(frame1);
        incomingController.add(frame2);
        await pumpEventQueue();

        expect(messages, ['hello world']);
      },
    );

    test(
      'rejects continuation frame without initial frame with Close Code 1002',
      () async {
        final errors = <Object>[];
        wsChannel.stream.listen((_) {}, onError: errors.add);

        final frame = _buildFrame(
          opcode: WebSocketOpcode.continuation,
          payload: [1, 2],
        );

        incomingController.add(frame);
        await pumpEventQueue();

        expect(wsChannel.closeCode, equals(1002));
      },
    );

    test('rejects fragmented control frame with Close Code 1002', () async {
      final errors = <Object>[];
      wsChannel.stream.listen((_) {}, onError: errors.add);

      final frame = _buildFrame(
        fin: false,
        opcode: WebSocketOpcode.ping,
      );

      incomingController.add(frame);
      await pumpEventQueue();

      expect(wsChannel.closeCode, equals(1002));
    });

    test('handles 64-bit extended payload length (len = 70000)', () async {
      final messages = <Object?>[];
      wsChannel.stream.listen(messages.add);

      final payload = List.generate(70000, (i) => i % 256);
      final frame = _buildFrame(
        opcode: WebSocketOpcode.binary,
        maskKey: [0x12, 0x34, 0x56, 0x78],
        payload: payload,
      );

      incomingController.add(frame);
      await pumpEventQueue();

      expect(messages.length, 1);
      expect((messages.first as Uint8List?)?.length, 70000);
      expect(messages.first as Uint8List?, equals(payload));
    });

    test(
      'sends binary frame with 64-bit extended payload length (len = 70000)',
      () async {
        final sentBytes = <List<int>>[];
        outgoingController.stream.listen(sentBytes.add);

        final payload = Uint8List(70000);
        for (var i = 0; i < 70000; i++) {
          payload[i] = i % 256;
        }

        wsChannel.sink.add(payload);
        await pumpEventQueue();

        final combined = Uint8List.fromList(
          sentBytes.expand((b) => b).toList(),
        );
        expect(combined.sublist(0, 2), equals([0x82, 0x7F]));
        expect(
          combined.sublist(2, 10),
          equals([0, 0, 0, 0, 0, 1, 0x11, 0x70]),
        );
        expect(combined.sublist(10), equals(payload));
      },
    );

    test(
      'rejects text frame with invalid UTF-8 payload with Close Code 1007',
      () async {
        final errors = <Object>[];
        wsChannel.stream.listen((_) {}, onError: errors.add);

        final frame = _buildFrame(
          opcode: WebSocketOpcode.text,
          maskKey: [0x00, 0x00, 0x00, 0x00],
          payload: [0xFF, 0xFF],
        );

        incomingController.add(frame);
        await pumpEventQueue();

        expect(wsChannel.closeCode, equals(1007));
      },
    );

    test(
      'rejects close frame with payload of length 1 with Close Code 1002',
      () async {
        final errors = <Object>[];
        wsChannel.stream.listen((_) {}, onError: errors.add);

        final frame = _buildFrame(
          opcode: WebSocketOpcode.close,
          maskKey: [0x00, 0x00, 0x00, 0x00],
          payload: [0x03],
        );

        incomingController.add(frame);
        await pumpEventQueue();

        expect(wsChannel.closeCode, equals(1002));
      },
    );

    test(
      'rejects close frame with invalid status code with Close Code 1002',
      () async {
        final errors = <Object>[];
        wsChannel.stream.listen((_) {}, onError: errors.add);

        final frame = _buildFrame(
          opcode: WebSocketOpcode.close,
          maskKey: [0x00, 0x00, 0x00, 0x00],
          payload: [0x03, 0xED], // 1005 (reserved code)
        );

        incomingController.add(frame);
        await pumpEventQueue();

        expect(wsChannel.closeCode, equals(1002));
      },
    );

    test(
      'rejects close frame with invalid UTF-8 reason with Close Code 1007',
      () async {
        final errors = <Object>[];
        wsChannel.stream.listen((_) {}, onError: errors.add);

        final frame = _buildFrame(
          opcode: WebSocketOpcode.close,
          maskKey: [0x00, 0x00, 0x00, 0x00],
          payload: [0x03, 0xE8, 0xFF, 0xFF],
        );

        incomingController.add(frame);
        await pumpEventQueue();

        expect(wsChannel.closeCode, equals(1007));
      },
    );

    test(
      'handles client-initiated close frame and responds with close frame',
      () async {
        final sentBytes = <List<int>>[];
        outgoingController.stream.listen(sentBytes.add);

        final reasonBytes = utf8.encode('client exit');
        final payload = [0x03, 0xE8, ...reasonBytes];

        final frame = _buildFrame(
          opcode: WebSocketOpcode.close,
          maskKey: [0x12, 0x34, 0x56, 0x78],
          payload: payload,
        );

        incomingController.add(frame);
        await pumpEventQueue();

        expect(wsChannel.closeCode, equals(1000));
        expect(wsChannel.closeReason, equals('client exit'));

        final combined = Uint8List.fromList(
          sentBytes.expand((b) => b).toList(),
        );
        expect(combined.sublist(0, 2), equals([0x88, payload.length]));
        expect((combined[2] << 8) | combined[3], equals(1000));
        expect(
          utf8.decode(combined.sublist(4, 2 + payload.length)),
          equals('client exit'),
        );
      },
    );

    test('rejects unknown opcode with Close Code 1002', () async {
      final errors = <Object>[];
      wsChannel.stream.listen((_) {}, onError: errors.add);

      final frame = _buildFrame(
        opcode: WebSocketOpcode.unknown,
        maskKey: [0x00, 0x00, 0x00, 0x00],
        payload: [0x00],
      );

      incomingController.add(frame);
      await pumpEventQueue();

      expect(wsChannel.closeCode, equals(1002));
    });

    test('handles incoming Pong frame silently', () async {
      final messages = <Object?>[];
      wsChannel.stream.listen(messages.add);

      final frame = _buildFrame(
        opcode: WebSocketOpcode.pong,
        maskKey: [0x01, 0x02, 0x03, 0x04],
      );

      incomingController.add(frame);
      await pumpEventQueue();

      expect(messages, isEmpty);
    });

    test(
      'rejects data frame while fragmentation is in progress with '
      'Close Code 1002',
      () async {
        final errors = <Object>[];
        wsChannel.stream.listen((_) {}, onError: errors.add);

        final frame1 = _buildFrame(
          fin: false,
          opcode: WebSocketOpcode.text,
          payload: utf8.encode('part 1'),
        );
        final frame2 = _buildFrame(
          opcode: WebSocketOpcode.text,
          payload: utf8.encode('part 2'),
        );

        incomingController.add(frame1);
        incomingController.add(frame2);
        await pumpEventQueue();

        expect(wsChannel.closeCode, equals(1002));
      },
    );

    test('rejects close code >= 5000 with Close Code 1002', () async {
      final errors = <Object>[];
      wsChannel.stream.listen((_) {}, onError: errors.add);

      final frame = _buildFrame(
        opcode: WebSocketOpcode.close,
        maskKey: [0x00, 0x00, 0x00, 0x00],
        payload: [0x13, 0x88], // 5000
      );

      incomingController.add(frame);
      await pumpEventQueue();

      expect(wsChannel.closeCode, equals(1002));
    });

    test(
      'rejects 64-bit payload length with MSB set with Close Code 1002',
      () async {
        final errors = <Object>[];
        wsChannel.stream.listen((_) {}, onError: errors.add);

        final bytes = <int>[
          0x82, // FIN + Binary
          0x80 | 127, // Masked + len 127
          0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, // MSB set
          0x00, 0x00, 0x00, 0x00, // Mask key
          0x00,
        ];

        incomingController.add(bytes);
        await pumpEventQueue();

        expect(wsChannel.closeCode, equals(1002));
      },
    );

    test(
      'rejects non-minimal 16-bit extended payload length with Close Code 1002',
      () async {
        final errors = <Object>[];
        wsChannel.stream.listen((_) {}, onError: errors.add);

        final bytes = <int>[
          0x81, // FIN + Text
          0x80 | 126, // Masked + len 126
          0x00, 0x05, // Non-minimal len 5
          0x00, 0x00, 0x00, 0x00, // Mask key
          ...utf8.encode('hello'),
        ];

        incomingController.add(bytes);
        await pumpEventQueue();

        expect(wsChannel.closeCode, equals(1002));
      },
    );

    test('does not send duplicate close frame when client responds to '
        'server close', () async {
      final sentBytes = <List<int>>[];
      outgoingController.stream.listen(sentBytes.add);

      // Server initiates close
      unawaited(wsChannel.sink.close(1000, 'bye'));
      await pumpEventQueue();

      final countBefore = sentBytes.length;

      // Client responds with close frame
      final clientCloseFrame = _buildFrame(
        opcode: WebSocketOpcode.close,
        maskKey: [0x00, 0x00, 0x00, 0x00],
        payload: [0x03, 0xE8],
      );

      incomingController.add(clientCloseFrame);
      await pumpEventQueue();

      // No second close frame should be sent
      expect(sentBytes.length, equals(countBefore));
    });

    test(
      'rejects RSV1 bit on continuation frame even if '
      'deflate enabled with 1002',
      () async {
        final ctrl = StreamChannelController<List<int>>(sync: true);
        final deflateWsChannel = StreamWebSocketChannel(
          ctrl.foreign,
          deflateOptions: WebSocketDeflateOptions.defaultConfig,
        );

        final frame = _buildFrame(
          opcode: WebSocketOpcode.continuation,
          maskKey: [0x11, 0x22, 0x33, 0x44],
          rsv1: true,
        );

        ctrl.local.sink.add(frame);
        await pumpEventQueue();

        expect(deflateWsChannel.closeCode, equals(1002));
      },
    );

    test(
      'rejects RSV1 bit on ping control frame even if '
      'deflate enabled with 1002',
      () async {
        final ctrl = StreamChannelController<List<int>>(sync: true);
        final deflateWsChannel = StreamWebSocketChannel(
          ctrl.foreign,
          deflateOptions: WebSocketDeflateOptions.defaultConfig,
        );

        final frame = _buildFrame(
          opcode: WebSocketOpcode.ping,
          maskKey: [0x11, 0x22, 0x33, 0x44],
          rsv1: true,
        );

        ctrl.local.sink.add(frame);
        await pumpEventQueue();

        expect(deflateWsChannel.closeCode, equals(1002));
      },
    );

    test(
      'closes with 1009 when decompressed message exceeds maxMessageSize',
      () async {
        final ctrl = StreamChannelController<List<int>>(sync: true);
        final deflateWsChannel = StreamWebSocketChannel(
          ctrl.foreign,
          maxMessageSize: 50,
          deflateOptions: WebSocketDeflateOptions.defaultConfig,
        );

        final rawData = Uint8List.fromList(List.filled(500, 0x41));
        final filter = RawZLibFilter.deflateFilter(raw: true);
        filter.process(rawData, 0, rawData.length);
        final b = BytesBuilder(copy: false);
        while (true) {
          final out = filter.processed();
          if (out == null) break;
          b.add(out);
        }
        var compressedPayload = b.takeBytes();
        if (compressedPayload.length >= 4 &&
            compressedPayload[compressedPayload.length - 4] == 0x00 &&
            compressedPayload[compressedPayload.length - 3] == 0x00 &&
            compressedPayload[compressedPayload.length - 2] == 0xff &&
            compressedPayload[compressedPayload.length - 1] == 0xff) {
          compressedPayload = compressedPayload.sublist(
            0,
            compressedPayload.length - 4,
          );
        }

        final frame = _buildFrame(
          opcode: WebSocketOpcode.text,
          payload: compressedPayload,
          maskKey: [0x11, 0x22, 0x33, 0x44],
          rsv1: true,
        );

        ctrl.local.sink.add(frame);
        await pumpEventQueue();

        expect(deflateWsChannel.closeCode, equals(1009));
        expect(
          deflateWsChannel.closeReason,
          contains('Exceeded maximum message size of 50 bytes'),
        );
      },
    );

    test(
      'sink.close(1005) sends empty close frame payload without code bytes',
      () async {
        final sentBytes = <List<int>>[];
        outgoingController.stream.listen(sentBytes.add);

        unawaited(wsChannel.sink.close(1005));
        await pumpEventQueue();

        expect(sentBytes, isNotEmpty);
        final closeFrameBytes = sentBytes.first;
        // Byte 0: 0x88 (FIN + Close opcode), Byte 1: 0x00 (Payload length 0)
        expect(closeFrameBytes[0], equals(0x88));
        expect(closeFrameBytes[1], equals(0x00));
      },
    );

    test(
      'rejects frame payload exceeding maxMessageSize with Close Code 1009',
      () async {
        final ctrl = StreamChannelController<List<int>>(sync: true);
        final limitedChannel = StreamWebSocketChannel(
          ctrl.foreign,
          maxMessageSize: 50,
        );

        final frame = _buildFrame(
          opcode: WebSocketOpcode.text,
          payload: List.filled(60, 0x61),
          maskKey: [0x11, 0x22, 0x33, 0x44],
        );

        ctrl.local.sink.add(frame);
        await pumpEventQueue();

        expect(limitedChannel.closeCode, equals(1009));
      },
    );

    test(
      'rejects accumulated fragmented message exceeding '
      'maxMessageSize with Close Code 1009',
      () async {
        final ctrl = StreamChannelController<List<int>>(sync: true);
        final limitedChannel = StreamWebSocketChannel(
          ctrl.foreign,
          maxMessageSize: 50,
        );

        final frame1 = _buildFrame(
          fin: false,
          opcode: WebSocketOpcode.text,
          payload: List.filled(30, 0x61),
          maskKey: [0x11, 0x22, 0x33, 0x44],
        );
        final frame2 = _buildFrame(
          opcode: WebSocketOpcode.continuation,
          payload: List.filled(30, 0x62),
          maskKey: [0x11, 0x22, 0x33, 0x44],
        );

        ctrl.local.sink.add(frame1);
        await pumpEventQueue();
        expect(limitedChannel.closeCode, isNull);

        ctrl.local.sink.add(frame2);
        await pumpEventQueue();
        expect(limitedChannel.closeCode, equals(1009));
      },
    );
  });
}

Uint8List _buildFrame({
  required int opcode,
  bool fin = true,
  int rsv = 0,
  bool rsv1 = false,
  bool masked = true,
  List<int> maskKey = const [0x12, 0x34, 0x56, 0x78],
  List<int> payload = const [],
  int? rawPayloadLength,
}) {
  final rsvBits = (rsv1 ? 4 : 0) | (rsv & 0x7);
  final bytes = <int>[];
  bytes.add((fin ? 0x80 : 0x00) | ((rsvBits & 0x7) << 4) | (opcode & 0x0F));

  final len = rawPayloadLength ?? payload.length;
  final maskBit = masked ? 0x80 : 0x00;

  if (len <= 125) {
    bytes.add(maskBit | len);
  } else if (len <= 65535) {
    bytes.add(maskBit | 126);
    bytes.add((len >> 8) & 0xFF);
    bytes.add(len & 0xFF);
  } else {
    bytes.add(maskBit | 127);
    for (var i = 7; i >= 0; i--) {
      bytes.add((len >> (i * 8)) & 0xFF);
    }
  }

  if (masked) {
    bytes.addAll(maskKey);
    for (var i = 0; i < payload.length; i++) {
      bytes.add(payload[i] ^ maskKey[i % 4]);
    }
  } else {
    bytes.addAll(payload);
  }

  return Uint8List.fromList(bytes);
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http_sse/http_sse.dart';
import 'package:test/test.dart';

void main() {
  group('SseEvent', () {
    test('formats simple text event correctly', () {
      const event = SseEvent.text('Hello World');
      expect(event.toFormattedString(), equals('data: Hello World\n\n'));
      expect(utf8.decode(event.toBytes()), equals('data: Hello World\n\n'));
    });

    test('formats text event with event name, id, and retry', () {
      const event = SseEvent.text(
        'Ping',
        event: 'message',
        id: '123',
        retry: Duration(milliseconds: 5000),
      );

      expect(
        event.toFormattedString(),
        equals(
          'event: message\n'
          'data: Ping\n'
          'id: 123\n'
          'retry: 5000\n\n',
        ),
      );
    });

    test('formats multiline text data into multiple data: lines', () {
      const event = SseEvent.text('line1\nline2\nline3');

      expect(
        event.toFormattedString(),
        equals(
          'data: line1\n'
          'data: line2\n'
          'data: line3\n\n',
        ),
      );
    });

    test('formats JSON event with event name, id, and retry correctly', () {
      const event = SseEvent.json(
        {'user': 'Alice', 'status': 'active'},
        event: 'user_status',
        id: 'evt-1',
        retry: Duration(milliseconds: 2000),
      );

      expect(
        event.toFormattedString(),
        equals(
          'event: user_status\n'
          'data: {"user":"Alice","status":"active"}\n'
          'id: evt-1\n'
          'retry: 2000\n\n',
        ),
      );
      expect(event.toBytes(), isNotEmpty);
    });

    test('formats comment event correctly', () {
      const event = SseEvent.comment('ping heartbeat');

      expect(event.toFormattedString(), equals(':ping heartbeat\n\n'));
    });

    test('sanitizes line breaks in event and id parameters', () {
      const event = SseEvent.text(
        'Payload',
        event: 'message\ninjected: true',
        id: '123\nfake_id: 999',
      );

      expect(
        event.toFormattedString(),
        equals(
          'event: messageinjected: true\n'
          'data: Payload\n'
          'id: 123fake_id: 999\n\n',
        ),
      );
    });

    test('supports equality, hashCode, and toString comparisons', () {
      const event1 = SseEvent.text('hello', id: '1');
      const event2 = SseEvent.text('hello', id: '1');
      const event3 = SseEvent.text('world', id: '1');

      expect(event1, equals(event2));
      expect(event1.hashCode, equals(event2.hashCode));
      expect(event1, isNot(equals(event3)));
      expect(event1.toString(), contains('SseTextEvent'));

      const json1 = SseEvent.json({
        'a': [1, 2],
      }, event: 'e');
      const json2 = SseEvent.json({
        'a': [1, 2],
      }, event: 'e');
      const json3 = SseEvent.json({
        'a': [1, 3],
      }, event: 'e');
      expect(json1, equals(json2));
      expect(json1.hashCode, equals(json2.hashCode));
      expect(json1, isNot(equals(json3)));
      expect(json1.toString(), contains('SseJsonEvent'));

      const comment1 = SseEvent.comment('ping');
      const comment2 = SseEvent.comment('ping');
      const comment3 = SseEvent.comment('pong');
      expect(comment1, equals(comment2));
      expect(comment1.hashCode, equals(comment2.hashCode));
      expect(comment1, isNot(equals(comment3)));
      expect(comment1.toString(), contains('SseCommentEvent'));
    });
  });

  group('SseEncoder', () {
    test('encodes stream of SseEvents into byte chunks', () async {
      final events = Stream.fromIterable([
        const SseEvent.text('event 1'),
        const SseEvent.text('event 2'),
      ]);

      final byteStream = events.transform(const SseEncoder());
      final bytesList = await byteStream.toList();

      expect(bytesList.length, equals(2));
      expect(utf8.decode(bytesList[0]), equals('data: event 1\n\n'));
      expect(utf8.decode(bytesList[1]), equals('data: event 2\n\n'));
    });
  });

  group('SseDecoder', () {
    test('decodes basic SSE stream with text events', () async {
      final raw = utf8.encode(
        'event: greeting\n'
        'data: Hello World\n'
        'id: 1\n\n',
      );

      final stream = Stream.value(Uint8List.fromList(raw));
      final decoded = await stream.transform(const SseDecoder()).toList();

      expect(decoded.length, equals(1));
      expect(decoded.first, isA<SseTextEvent>());
      final textEvent = decoded.first as SseTextEvent;
      expect(textEvent.data, equals('Hello World'));
      expect(textEvent.event, equals('greeting'));
      expect(textEvent.id, equals('1'));
    });

    test(r'strips leading UTF-8 Byte Order Mark (BOM \uFEFF)', () async {
      final raw = utf8.encode(
        '\uFEFFdata: hello bom\n\n',
      );

      final stream = Stream.value(Uint8List.fromList(raw));
      final decoded = await stream.transform(const SseDecoder()).toList();

      expect(decoded.length, equals(1));
      expect((decoded.first as SseTextEvent).data, equals('hello bom'));
    });

    test('decodes JSON events when data is valid JSON', () async {
      final raw = utf8.encode(
        'event: user_created\n'
        'data: {"id":42,"name":"Bob"}\n'
        'id: evt-42\n'
        'retry: 3000\n\n',
      );

      final stream = Stream.value(Uint8List.fromList(raw));
      final decoded = await stream.transform(const SseDecoder()).toList();

      expect(decoded.length, equals(1));
      expect(decoded.first, isA<SseJsonEvent>());
      final jsonEvent = decoded.first as SseJsonEvent;
      expect(jsonEvent.data, equals({'id': 42, 'name': 'Bob'}));
      expect(jsonEvent.event, equals('user_created'));
      expect(jsonEvent.id, equals('evt-42'));
      expect(jsonEvent.retry, equals(const Duration(milliseconds: 3000)));
    });

    test('ignores non-digits retry values', () async {
      final raw = utf8.encode(
        'retry: 3000abc\n'
        'data: hello\n\n'
        'retry: 5000\n'
        'data: world\n\n',
      );

      final stream = Stream.value(Uint8List.fromList(raw));
      final decoded = await stream.transform(const SseDecoder()).toList();

      expect(decoded.length, equals(2));
      expect(decoded[0].retry, isNull);
      expect(decoded[1].retry, equals(const Duration(milliseconds: 5000)));
    });

    test('handles empty id field resetting id to empty string', () async {
      final raw = utf8.encode(
        'id: 100\n'
        'data: event 1\n\n'
        'id\n'
        'data: event 2\n\n',
      );

      final stream = Stream.value(Uint8List.fromList(raw));
      final decoded = await stream.transform(const SseDecoder()).toList();

      expect(decoded.length, equals(2));
      expect(decoded[0].id, equals('100'));
      expect(decoded[1].id, equals(''));
    });

    test(
      'decodes multiline data fields into single string with newlines',
      () async {
        final raw = utf8.encode(
          'data: first line\n'
          'data: second line\n'
          'data: third line\n\n',
        );

        final stream = Stream.value(Uint8List.fromList(raw));
        final decoded = await stream.transform(const SseDecoder()).toList();

        expect(decoded.length, equals(1));
        expect(decoded.first, isA<SseTextEvent>());
        final textEvent = decoded.first as SseTextEvent;
        expect(textEvent.data, equals('first line\nsecond line\nthird line'));
      },
    );

    test(r'handles CRLF (\r\n) and CR (\r) line endings', () async {
      final raw = utf8.encode(
        'event: crlf\r\ndata: line1\r\ndata: line2\r\n\r\n'
        'event: cr\rdata: cr_line\r\r',
      );

      final stream = Stream.value(Uint8List.fromList(raw));
      final decoded = await stream.transform(const SseDecoder()).toList();

      expect(decoded.length, equals(2));
      expect(decoded[0].event, equals('crlf'));
      expect((decoded[0] as SseTextEvent).data, equals('line1\nline2'));
      expect(decoded[1].event, equals('cr'));
      expect((decoded[1] as SseTextEvent).data, equals('cr_line'));
    });

    test(
      'ignores comments by default and emits comments when emitComments: true',
      () async {
        final raw = utf8.encode(
          ': ping heartbeat\n\n'
          ':nospace_comment\n\n'
          'data: Hello\n\n',
        );

        // Default (emitComments: false)
        final decodedDefault = await Stream.value(
          Uint8List.fromList(raw),
        ).transform(const SseDecoder()).toList();
        expect(decodedDefault.length, equals(1));
        expect(decodedDefault.first, isA<SseTextEvent>());

        // With emitComments: true
        final decodedComments = await Stream.value(
          Uint8List.fromList(raw),
        ).transform(const SseDecoder(emitComments: true)).toList();
        expect(decodedComments.length, equals(3));
        expect(
          decodedComments[0],
          equals(const SseCommentEvent('ping heartbeat')),
        );
        expect(
          decodedComments[1],
          equals(const SseCommentEvent('nospace_comment')),
        );
        expect(decodedComments[2], isA<SseTextEvent>());
      },
    );

    test('handles byte chunks split across lines and fields', () async {
      final chunk1 = utf8.encode('event: test\ndat');
      final chunk2 = utf8.encode('a: hello\n\nevent: test2\ndata: wor');
      final chunk3 = utf8.encode('ld\n\n');

      final controller = StreamController<Uint8List>();
      final decodedFuture = controller.stream
          .transform(const SseDecoder())
          .toList();

      controller.add(Uint8List.fromList(chunk1));
      controller.add(Uint8List.fromList(chunk2));
      controller.add(Uint8List.fromList(chunk3));
      await controller.close();

      final decoded = await decodedFuture;
      expect(decoded.length, equals(2));
      expect((decoded[0] as SseTextEvent).data, equals('hello'));
      expect((decoded[1] as SseTextEvent).data, equals('world'));
    });

    test(
      'flushes trailing event (text or json) if stream ends without trailing '
      'empty line',
      () async {
        final textStream = Stream.value(
          Uint8List.fromList(utf8.encode('data: no trailing newline')),
        );
        final textDecoded = await textStream
            .transform(const SseDecoder())
            .toList();
        expect(textDecoded.length, equals(1));
        expect(
          (textDecoded.first as SseTextEvent).data,
          equals('no trailing newline'),
        );

        final jsonStream = Stream.value(
          Uint8List.fromList(utf8.encode('data: {"trailing":true}')),
        );
        final jsonDecoded = await jsonStream
            .transform(const SseDecoder())
            .toList();
        expect(jsonDecoded.length, equals(1));
        expect(
          (jsonDecoded.first as SseJsonEvent).data,
          equals({'trailing': true}),
        );
      },
    );
  });
}

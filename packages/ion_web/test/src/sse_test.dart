import 'dart:convert';

import 'package:ion_web/ion_web.dart';
import 'package:test/test.dart';

void main() {
  group('SseEvent', () {
    test('formats simple text event', () {
      const event = SseEvent.text('Hello World');
      final text = utf8.decode(event.toBytes());

      expect(text, equals('data: Hello World\n\n'));
    });

    test('formats text event with event, id, and retry', () {
      const event = SseEvent.text(
        'Ping',
        event: 'message',
        id: '123',
        retry: Duration(milliseconds: 5000),
      );
      final text = utf8.decode(event.toBytes());

      expect(
        text,
        equals(
          'event: message\n'
          'data: Ping\n'
          'id: 123\n'
          'retry: 5000\n\n',
        ),
      );
    });

    test('formats multiline text data with multiple data: lines', () {
      const event = SseEvent.text('line1\nline2\nline3');
      final text = utf8.decode(event.toBytes());

      expect(
        text,
        equals(
          'data: line1\n'
          'data: line2\n'
          'data: line3\n\n',
        ),
      );
    });

    test('formats JSON event', () {
      const event = SseEvent.json(
        {'user': 'Alice', 'status': 'active'},
        event: 'user_status',
        id: 'evt-1',
      );
      final text = utf8.decode(event.toBytes());

      expect(
        text,
        equals(
          'event: user_status\n'
          'data: {"user":"Alice","status":"active"}\n'
          'id: evt-1\n\n',
        ),
      );
    });

    test(
      'sanitizes line breaks in event and id parameters to prevent injection',
      () {
        const event = SseEvent.text(
          'Payload',
          event: 'message\ninjected: true',
          id: '123\nfake_id: 999',
        );
        final text = utf8.decode(event.toBytes());

        expect(
          text,
          equals(
            'event: messageinjected: true\n'
            'data: Payload\n'
            'id: 123fake_id: 999\n\n',
          ),
        );
      },
    );
  });
}

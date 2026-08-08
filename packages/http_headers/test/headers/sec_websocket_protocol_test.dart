import 'package:http_headers/http_headers.dart';
import 'package:test/test.dart';

void main() {
  group('SecWebSocketProtocolHeader', () {
    test('encodes single and multiple subprotocols', () {
      final single = TypedHeader.secWebSocketProtocolSingle('chat');
      expect(single.encode(), equals(['chat']));

      const multi = SecWebSocketProtocolHeader(['chat', 'superchat']);
      expect(multi.encode(), equals(['chat, superchat']));
    });

    test('decodes CSV values', () {
      final decoded = SecWebSocketProtocolHeader.decode(['chat, superchat']);
      expect(
        decoded,
        equals(const SecWebSocketProtocolHeader(['chat', 'superchat'])),
      );
    });
  });
}

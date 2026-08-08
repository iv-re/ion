import 'package:http_headers/src/headers/sec_websocket_version.dart';
import 'package:test/test.dart';

void main() {
  group('SecWebSocketVersionHeader', () {
    test('decodes version 13 correctly', () {
      final header = SecWebSocketVersionHeader.decode(['13']);
      expect(header, equals(const SecWebSocketVersionHeader.v13()));
      expect(header?.version, equals(13));
      expect(header?.encode(), equals(['13']));
    });

    test('decodes custom version number correctly', () {
      final header = SecWebSocketVersionHeader.decode(['8']);
      expect(header?.version, equals(8));
      expect(header?.encode(), equals(['8']));
    });

    test('returns null for non-integer or empty values', () {
      expect(SecWebSocketVersionHeader.decode(['invalid']), isNull);
      expect(SecWebSocketVersionHeader.decode([]), isNull);
    });
  });
}

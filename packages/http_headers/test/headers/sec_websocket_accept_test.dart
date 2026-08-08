import 'package:http_headers/src/headers/sec_websocket_accept.dart';
import 'package:test/test.dart';

void main() {
  group('SecWebSocketAcceptHeader', () {
    test('decodes base64 accept key correctly', () {
      final header = SecWebSocketAcceptHeader.decode([
        's3pPLMBiTxaQ9kYGzzhZRbK+xOo=',
      ]);
      expect(header, isA<SecWebSocketAcceptHeader>());
      expect(header?.value, equals('s3pPLMBiTxaQ9kYGzzhZRbK+xOo='));
      expect(
        header?.encode(),
        equals(['s3pPLMBiTxaQ9kYGzzhZRbK+xOo=']),
      );
    });

    test('returns null for empty values', () {
      expect(SecWebSocketAcceptHeader.decode([]), isNull);
      expect(SecWebSocketAcceptHeader.decode(['   ']), isNull);
    });
  });
}

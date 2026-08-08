import 'package:http_headers/http_headers.dart';
import 'package:test/test.dart';

void main() {
  group('SecWebSocketExtensionsHeader', () {
    test('encodes extensions', () {
      const ext = SecWebSocketExtensionsHeader(
        perMessageDeflate: true,
        clientNoContextTakeover: true,
      );
      expect(
        ext.encode(),
        equals(['permessage-deflate; client_no_context_takeover']),
      );
    });

    test('decodes raw header values', () {
      final decoded = SecWebSocketExtensionsHeader.decode([
        // ignore: lines_longer_than_80_chars
        'permessage-deflate; client_no_context_takeover; server_no_context_takeover',
      ]);
      expect(
        decoded,
        equals(
          const SecWebSocketExtensionsHeader(
            perMessageDeflate: true,
            clientNoContextTakeover: true,
            serverNoContextTakeover: true,
          ),
        ),
      );
    });
  });
}

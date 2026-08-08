import 'dart:convert';

import 'package:http_headers/src/headers/sec_websocket_key.dart';
import 'package:test/test.dart';

void main() {
  group('SecWebSocketKeyHeader', () {
    test('decodes base64 nonce key correctly', () {
      final header = SecWebSocketKeyHeader.decode([
        'dGhlIHNhbXBsZSBub25jZQ==',
      ]);
      expect(header, isA<SecWebSocketKeyHeader>());
      expect(header?.value, equals('dGhlIHNhbXBsZSBub25jZQ=='));
      expect(header?.key, equals('dGhlIHNhbXBsZSBub25jZQ=='));
      expect(
        header?.encode(),
        equals(['dGhlIHNhbXBsZSBub25jZQ==']),
      );
    });

    test('creates key from raw bytes', () {
      final bytes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];
      final fromBytes = SecWebSocketKeyHeader.fromBytes(bytes);
      expect(
        fromBytes.encode(),
        equals([base64.encode(bytes)]),
      );
    });

    test('returns null for empty values', () {
      expect(SecWebSocketKeyHeader.decode([]), isNull);
      expect(SecWebSocketKeyHeader.decode(['   ']), isNull);
    });
  });
}

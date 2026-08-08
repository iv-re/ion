import 'package:http_headers/src/headers/upgrade.dart';
import 'package:test/test.dart';

void main() {
  group('UpgradeHeader', () {
    test('decodes protocol list correctly', () {
      final header = UpgradeHeader.decode(['websocket']);
      expect(header, isA<UpgradeHeader>());
      expect(header?.protocols, equals(['websocket']));
      expect(header?.encode(), equals(['websocket']));
    });

    test('websocket constructor works correctly', () {
      const ws = UpgradeHeader.websocket();
      expect(ws.protocols, equals(['websocket']));
      expect(ws.encode(), equals(['websocket']));
    });

    test('returns null for empty values', () {
      expect(UpgradeHeader.decode([]), isNull);
    });
  });
}

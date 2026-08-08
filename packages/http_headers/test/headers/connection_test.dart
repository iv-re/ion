import 'package:http_headers/src/headers/connection.dart';
import 'package:test/test.dart';

void main() {
  group('ConnectionHeader', () {
    test('decodes keep-alive and upgrade options correctly', () {
      final header = ConnectionHeader.decode(['keep-alive, upgrade']);
      expect(header, isNotNull);
      expect(header?.isKeepAlive, isTrue);
      expect(header?.isUpgrade, isTrue);
      expect(header?.isClose, isFalse);
      expect(header?.encode(), equals(['keep-alive, upgrade']));
    });

    test('decodes close option correctly', () {
      final header = ConnectionHeader.decode(['close']);
      expect(header?.isClose, isTrue);
      expect(header?.isKeepAlive, isFalse);
      expect(header?.encode(), equals(['close']));
    });

    test('returns null for empty values', () {
      expect(ConnectionHeader.decode([]), isNull);
    });
  });
}

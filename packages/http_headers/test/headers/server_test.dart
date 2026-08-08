import 'package:http_headers/src/headers/server.dart';
import 'package:test/test.dart';

void main() {
  group('ServerHeader', () {
    test('decodes server info string correctly', () {
      final header = ServerHeader.decode(['CERN/3.0 libwww/2.17']);
      expect(header, isA<ServerHeader>());
      expect(header?.value, equals('CERN/3.0 libwww/2.17'));
      expect(header?.encode(), equals(['CERN/3.0 libwww/2.17']));
    });

    test('returns null for empty values', () {
      expect(ServerHeader.decode([]), isNull);
      expect(ServerHeader.decode(['   ']), isNull);
    });
  });
}

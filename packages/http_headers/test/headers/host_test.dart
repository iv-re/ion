import 'package:http_headers/src/headers/host.dart';
import 'package:test/test.dart';

void main() {
  group('HostHeader', () {
    test('decodes host with port correctly', () {
      final header = HostHeader.decode(['example.com:8080']);
      expect(header, isA<HostHeader>());
      expect(header?.host, equals('example.com'));
      expect(header?.port, equals(8080));
      expect(header?.isValid, isTrue);
      expect(header?.encode(), equals(['example.com:8080']));
    });

    test('decodes host without port correctly', () {
      final header = HostHeader.decode(['example.com']);
      expect(header?.host, equals('example.com'));
      expect(header?.port, isNull);
      expect(header?.isValid, isTrue);
      expect(header?.encode(), equals(['example.com']));
    });

    test(
      'validates host syntax correctly and returns null for invalid host',
      () {
        expect(HostHeader.decode(['user@host/path']), isNull);
      },
    );

    test('returns null when multiple host values are present', () {
      expect(HostHeader.decode(['example.com', 'evil.com']), isNull);
    });

    test('returns null for empty values', () {
      expect(HostHeader.decode([]), isNull);
    });
  });
}

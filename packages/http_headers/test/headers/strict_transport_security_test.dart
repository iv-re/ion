import 'package:http_headers/src/headers/strict_transport_security.dart';
import 'package:test/test.dart';

void main() {
  group('StrictTransportSecurityHeader', () {
    test('decodes max-age and includeSubdomains correctly', () {
      final header = StrictTransportSecurityHeader.decode([
        'max-age=31536000; includeSubdomains',
      ]);
      expect(header, isA<StrictTransportSecurityHeader>());
      expect(header?.maxAge, equals(const Duration(seconds: 31536000)));
      expect(header?.includeSubdomains, isTrue);
      expect(
        header?.encode(),
        equals(['max-age=31536000; includeSubdomains']),
      );
    });

    test('encodes simple HSTS without subdomains correctly', () {
      const simpleHsts = StrictTransportSecurityHeader.excludingSubdomains(
        Duration(seconds: 3600),
      );
      expect(simpleHsts.encode(), equals(['max-age=3600']));
    });

    test('returns null for missing max-age or empty values', () {
      expect(
        StrictTransportSecurityHeader.decode(['includeSubdomains']),
        isNull,
      );
      expect(StrictTransportSecurityHeader.decode([]), isNull);
    });
  });
}

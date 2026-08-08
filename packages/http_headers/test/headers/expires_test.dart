import 'dart:io';

import 'package:http_headers/src/headers/expires.dart';
import 'package:test/test.dart';

void main() {
  group('ExpiresHeader', () {
    test('decodes HTTP date correctly', () {
      final header = ExpiresHeader.decode(['Thu, 01 Dec 1994 16:00:00 GMT']);
      expect(header, isA<ExpiresHeader>());
      expect(
        header?.date,
        equals(HttpDate.parse('Thu, 01 Dec 1994 16:00:00 GMT')),
      );
      expect(
        header?.encode(),
        equals(['Thu, 01 Dec 1994 16:00:00 GMT']),
      );
    });

    test('returns null for invalid date or empty values', () {
      expect(ExpiresHeader.decode(['not-a-date']), isNull);
      expect(ExpiresHeader.decode([]), isNull);
    });
  });
}

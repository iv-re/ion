import 'dart:io';

import 'package:http_headers/src/headers/last_modified.dart';
import 'package:test/test.dart';

void main() {
  group('LastModifiedHeader', () {
    test('decodes HTTP date correctly', () {
      final header = LastModifiedHeader.decode([
        'Sat, 29 Oct 1994 19:43:31 GMT',
      ]);
      expect(header, isA<LastModifiedHeader>());
      expect(
        header?.date,
        equals(HttpDate.parse('Sat, 29 Oct 1994 19:43:31 GMT')),
      );
      expect(
        header?.encode(),
        equals(['Sat, 29 Oct 1994 19:43:31 GMT']),
      );
    });

    test('returns null for invalid date or empty values', () {
      expect(LastModifiedHeader.decode(['invalid']), isNull);
      expect(LastModifiedHeader.decode([]), isNull);
    });
  });
}

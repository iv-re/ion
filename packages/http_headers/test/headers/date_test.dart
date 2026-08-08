import 'dart:io';

import 'package:http_headers/src/headers/date.dart';
import 'package:test/test.dart';

void main() {
  group('DateHeader', () {
    test('decodes HTTP date correctly', () {
      final header = DateHeader.decode(['Tue, 15 Nov 1994 08:12:31 GMT']);
      expect(header, isA<DateHeader>());
      expect(
        header?.date,
        equals(HttpDate.parse('Tue, 15 Nov 1994 08:12:31 GMT')),
      );
      expect(
        header?.encode(),
        equals(['Tue, 15 Nov 1994 08:12:31 GMT']),
      );
    });

    test('returns null for invalid date or empty values', () {
      expect(DateHeader.decode(['invalid-date']), isNull);
      expect(DateHeader.decode([]), isNull);
    });
  });
}

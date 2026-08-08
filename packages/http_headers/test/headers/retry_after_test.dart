import 'dart:io';

import 'package:http_headers/src/headers/retry_after.dart';
import 'package:test/test.dart';

void main() {
  group('RetryAfterHeader', () {
    test('decodes delay seconds correctly', () {
      final header = RetryAfterHeader.decode(['120']);
      expect(header, isA<RetryAfterDelay>());
      if (header is RetryAfterDelay) {
        expect(header.duration, equals(const Duration(seconds: 120)));
      }
      expect(header?.encode(), equals(['120']));
    });

    test('decodes date variant correctly', () {
      final header = RetryAfterHeader.decode([
        'Thu, 01 Dec 1994 16:00:00 GMT',
      ]);
      expect(header, isA<RetryAfterDate>());
      if (header is RetryAfterDate) {
        expect(
          header.date,
          equals(HttpDate.parse('Thu, 01 Dec 1994 16:00:00 GMT')),
        );
      }
      expect(
        header?.encode(),
        equals(['Thu, 01 Dec 1994 16:00:00 GMT']),
      );
    });

    test('returns null for invalid values', () {
      expect(RetryAfterHeader.decode(['invalid-value']), isNull);
      expect(RetryAfterHeader.decode([]), isNull);
    });
  });
}

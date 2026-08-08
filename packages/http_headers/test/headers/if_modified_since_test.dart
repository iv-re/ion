import 'dart:io';

import 'package:http_headers/src/headers/if_modified_since.dart';
import 'package:test/test.dart';

void main() {
  group('IfModifiedSinceHeader', () {
    test('decodes date correctly and checks isModified', () {
      final header = IfModifiedSinceHeader.decode([
        'Sat, 29 Oct 1994 19:43:31 GMT',
      ]);
      expect(header, isA<IfModifiedSinceHeader>());
      final expectedDt = HttpDate.parse('Sat, 29 Oct 1994 19:43:31 GMT');
      expect(header?.date, equals(expectedDt));
      expect(
        header?.isModified(expectedDt.add(const Duration(seconds: 10))),
        isTrue,
      );
      expect(
        header?.encode(),
        equals(['Sat, 29 Oct 1994 19:43:31 GMT']),
      );
    });

    test('returns null for invalid date or empty values', () {
      expect(IfModifiedSinceHeader.decode(['invalid']), isNull);
      expect(IfModifiedSinceHeader.decode([]), isNull);
    });
  });
}

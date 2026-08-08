import 'dart:io';

import 'package:http_headers/src/headers/if_unmodified_since.dart';
import 'package:test/test.dart';

void main() {
  group('IfUnmodifiedSinceHeader', () {
    test('decodes date correctly and checks preconditionPasses', () {
      final header = IfUnmodifiedSinceHeader.decode([
        'Sat, 29 Oct 1994 19:43:31 GMT',
      ]);
      expect(header, isA<IfUnmodifiedSinceHeader>());
      final expectedDt = HttpDate.parse('Sat, 29 Oct 1994 19:43:31 GMT');
      expect(header?.date, equals(expectedDt));
      expect(
        header?.preconditionPasses(expectedDt),
        isTrue,
      );
      expect(
        header?.encode(),
        equals(['Sat, 29 Oct 1994 19:43:31 GMT']),
      );
    });

    test('returns null for invalid date or empty values', () {
      expect(IfUnmodifiedSinceHeader.decode(['invalid']), isNull);
      expect(IfUnmodifiedSinceHeader.decode([]), isNull);
    });
  });
}

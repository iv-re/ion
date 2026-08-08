import 'dart:io';

import 'package:http_headers/src/headers/etag.dart';
import 'package:http_headers/src/headers/if_range.dart';
import 'package:http_headers/src/headers/last_modified.dart';
import 'package:test/test.dart';

void main() {
  group('IfRangeHeader', () {
    test('decodes ETag variant correctly and checks isModified', () {
      final header = IfRangeHeader.decode(['"xyzzy"']);
      expect(header, isA<IfRangeETag>());
      expect(
        (header as IfRangeETag?)?.etag,
        equals(ETagHeader.strong('xyzzy')),
      );
      expect(header?.encode(), equals(['"xyzzy"']));
      expect(
        header?.isModified(etag: ETagHeader.strong('xyzzy')),
        isFalse,
      );
    });

    test('decodes Date variant correctly and checks isModified', () {
      final header = IfRangeHeader.decode(['Tue, 15 Nov 1994 08:12:31 GMT']);
      expect(header, isA<IfRangeDate>());
      expect(
        header?.encode(),
        equals(['Tue, 15 Nov 1994 08:12:31 GMT']),
      );
      final dt = HttpDate.parse('Tue, 15 Nov 1994 08:12:31 GMT');
      expect(
        header?.isModified(
          lastModified: LastModifiedHeader(dt.add(const Duration(hours: 1))),
        ),
        isTrue,
      );
    });

    test('returns null for invalid values', () {
      expect(IfRangeHeader.decode(['invalid-value']), isNull);
      expect(IfRangeHeader.decode([]), isNull);
    });
  });
}

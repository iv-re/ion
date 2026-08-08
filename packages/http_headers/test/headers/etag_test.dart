import 'package:http_headers/src/entity_tag.dart';
import 'package:http_headers/src/headers/etag.dart';
import 'package:test/test.dart';

void main() {
  group('ETagHeader', () {
    test('decodes strong ETag correctly', () {
      final header = ETagHeader.decode(['"xyzzy"']);
      expect(header, isA<ETagHeader>());
      expect(header?.tag, equals(const EntityTag('xyzzy')));
      expect(header?.isWeak, isFalse);
      expect(header?.encode(), equals(['"xyzzy"']));
    });

    test('decodes weak ETag correctly', () {
      final header = ETagHeader.decode(['W/"xyzzy"']);
      expect(header, isA<ETagHeader>());
      expect(header?.tag, equals(const EntityTag.weak('xyzzy')));
      expect(header?.isWeak, isTrue);
      expect(header?.encode(), equals(['W/"xyzzy"']));
    });

    test('parses EntityTag directly and returns null for invalid tags', () {
      expect(EntityTag.parse('invalid'), isNull);
      expect(ETagHeader.decode(['invalid']), isNull);
      expect(ETagHeader.decode([]), isNull);
    });
  });
}

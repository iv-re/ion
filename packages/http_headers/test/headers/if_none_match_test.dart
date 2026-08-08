import 'package:http_headers/src/entity_tag.dart';
import 'package:http_headers/src/headers/etag.dart';
import 'package:http_headers/src/headers/if_none_match.dart';
import 'package:test/test.dart';

void main() {
  group('IfNoneMatchHeader', () {
    test('decodes wildcard If-None-Match:* correctly', () {
      final header = IfNoneMatchHeader.decode(['*']);
      expect(header, isA<IfNoneMatchAny>());
      expect(header?.isAny, isTrue);
      expect(header?.encode(), equals(['*']));
      expect(
        header?.preconditionPasses(const ETagHeader(EntityTag('xyzzy'))),
        isFalse,
      );
    });

    test('decodes list of ETags correctly and evaluates precondition', () {
      final header = IfNoneMatchHeader.decode(['"xyzzy", "737023"']);
      expect(header, isA<IfNoneMatchItems>());
      expect(header?.isAny, isFalse);
      expect(header?.encode(), equals(['"xyzzy", "737023"']));
      expect(
        header?.preconditionPasses(const ETagHeader(EntityTag('xyzzy'))),
        isFalse,
      );
      expect(
        header?.preconditionPasses(const ETagHeader(EntityTag('other'))),
        isTrue,
      );
    });

    test('returns null for empty or invalid values', () {
      expect(IfNoneMatchHeader.decode([]), isNull);
      expect(IfNoneMatchHeader.decode(['invalid']), isNull);
    });
  });
}

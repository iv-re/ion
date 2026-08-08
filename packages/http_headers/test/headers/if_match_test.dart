import 'package:http_headers/src/entity_tag.dart';
import 'package:http_headers/src/headers/etag.dart';
import 'package:http_headers/src/headers/if_match.dart';
import 'package:test/test.dart';

void main() {
  group('IfMatchHeader', () {
    test('decodes wildcard If-Match:* correctly', () {
      final header = IfMatchHeader.decode(['*']);
      expect(header, isA<IfMatchAny>());
      expect(header?.isAny, isTrue);
      expect(header?.encode(), equals(['*']));
      expect(
        header?.preconditionPasses(const ETagHeader(EntityTag('xyzzy'))),
        isTrue,
      );
    });

    test('decodes list of ETags correctly and evaluates precondition', () {
      final header = IfMatchHeader.decode(['"xyzzy", "737023"']);
      expect(header, isA<IfMatchItems>());
      expect(header?.isAny, isFalse);
      expect(header?.encode(), equals(['"xyzzy", "737023"']));
      expect(
        header?.preconditionPasses(const ETagHeader(EntityTag('xyzzy'))),
        isTrue,
      );
      expect(
        header?.preconditionPasses(const ETagHeader(EntityTag.weak('xyzzy'))),
        isFalse,
      );
    });

    test('returns null for empty or invalid values', () {
      expect(IfMatchHeader.decode([]), isNull);
      expect(IfMatchHeader.decode(['invalid']), isNull);
    });
  });
}

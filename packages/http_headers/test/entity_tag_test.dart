import 'package:http_headers/src/entity_tag.dart';
import 'package:test/test.dart';

void main() {
  group('EntityTag', () {
    group('constructors', () {
      test('default constructor creates strong tag by default', () {
        const tag = EntityTag('xyzzy');
        expect(tag.tag, equals('xyzzy'));
        expect(tag.isWeak, isFalse);
      });

      test('default constructor allows setting isWeak explicitly', () {
        const tag = EntityTag('xyzzy', isWeak: true);
        expect(tag.tag, equals('xyzzy'));
        expect(tag.isWeak, isTrue);
      });

      test('weak constructor creates weak tag', () {
        const tag = EntityTag.weak('xyzzy');
        expect(tag.tag, equals('xyzzy'));
        expect(tag.isWeak, isTrue);
      });

      test('strong constructor creates strong tag', () {
        const tag = EntityTag.strong('xyzzy');
        expect(tag.tag, equals('xyzzy'));
        expect(tag.isWeak, isFalse);
      });
    });

    group('parse', () {
      test('parses valid strong tags', () {
        final tag = EntityTag.parse('"xyzzy"');
        expect(tag, equals(const EntityTag('xyzzy')));
        expect(tag?.isWeak, isFalse);
      });

      test('parses valid weak tags', () {
        final tag = EntityTag.parse('W/"xyzzy"');
        expect(tag, equals(const EntityTag.weak('xyzzy')));
        expect(tag?.isWeak, isTrue);
      });

      test('trims leading and trailing whitespace', () {
        final tagStrong = EntityTag.parse('  "xyzzy"  ');
        expect(tagStrong, equals(const EntityTag('xyzzy')));

        final tagWeak = EntityTag.parse('  W/"xyzzy"  ');
        expect(tagWeak, equals(const EntityTag.weak('xyzzy')));
      });

      test('parses empty tag inside quotes', () {
        final tagStrong = EntityTag.parse('""');
        expect(tagStrong, equals(const EntityTag('')));

        final tagWeak = EntityTag.parse('W/""');
        expect(tagWeak, equals(const EntityTag.weak('')));
      });

      test('returns null for invalid inputs', () {
        expect(EntityTag.parse(''), isNull);
        expect(EntityTag.parse('   '), isNull);
        expect(EntityTag.parse('xyzzy'), isNull);
        expect(EntityTag.parse('"xyzzy'), isNull);
        expect(EntityTag.parse('xyzzy"'), isNull);
        expect(EntityTag.parse('w/"xyzzy"'), isNull);
        expect(EntityTag.parse('W/xyzzy'), isNull);
        expect(EntityTag.parse('"xy"zzy"'), isNull);
        expect(EntityTag.parse('W/"xy"zzy"'), isNull);
        expect(EntityTag.parse('W/'), isNull);
        expect(EntityTag.parse('"'), isNull);
      });
    });

    group('toString', () {
      test('formats strong entity tag correctly', () {
        expect(const EntityTag('xyzzy').toString(), equals('"xyzzy"'));
      });

      test('formats weak entity tag correctly', () {
        expect(const EntityTag.weak('xyzzy').toString(), equals('W/"xyzzy"'));
      });
    });

    group('equality & props', () {
      test('supports value equality', () {
        expect(const EntityTag('xyzzy'), equals(const EntityTag('xyzzy')));
        expect(
          const EntityTag.weak('xyzzy'),
          equals(const EntityTag.weak('xyzzy')),
        );
        expect(
          const EntityTag('xyzzy'),
          isNot(equals(const EntityTag.weak('xyzzy'))),
        );
        expect(
          const EntityTag('xyzzy'),
          isNot(equals(const EntityTag('other'))),
        );
      });

      test('props contain tag and isWeak', () {
        const tag = EntityTag('xyzzy', isWeak: true);
        expect(tag.props, equals(['xyzzy', true]));
      });
    });
  });
}

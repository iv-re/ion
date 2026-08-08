import 'package:ion_extra/src/utils.dart';
import 'package:test/test.dart';

void main() {
  group('typeNameOf', () {
    test('returns canonical name for Map variants', () {
      expect(typeNameOf<Map<String, Object?>>(), equals('map'));
      expect(typeNameOf<Map<String, dynamic>>(), equals('map'));
      expect(typeNameOf<Map<int, String>>(), equals('map'));
      expect(typeNameOf<Map<Object, Object>>(), equals('map'));
    });

    test('returns canonical name for List variants', () {
      expect(typeNameOf<List<Object?>>(), equals('list'));
      expect(typeNameOf<List<dynamic>>(), equals('list'));
      expect(typeNameOf<List<String>>(), equals('list'));
      expect(typeNameOf<List<int>>(), equals('list'));
    });

    test('returns canonical name for primitives', () {
      expect(typeNameOf<String>(), equals('string'));
      expect(typeNameOf<int>(), equals('int'));
      expect(typeNameOf<double>(), equals('double'));
      expect(typeNameOf<num>(), equals('number'));
      expect(typeNameOf<bool>(), equals('bool'));
    });

    test('returns toString() for custom and other types', () {
      expect(typeNameOf<Object>(), equals('Object'));
      expect(typeNameOf<Set<String>>(), equals('Set<String>'));
      expect(typeNameOf<_CustomClass>(), equals('_CustomClass'));
    });
  });
}

class _CustomClass {}

import 'package:checks/checks.dart';
import 'package:ion_extra/src/utils.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('typeNameOf', () {
    test('returns canonical name for Map variants', () {
      check(typeNameOf<Map<String, Object?>>()).equals('map');
      check(typeNameOf<Map<String, dynamic>>()).equals('map');
      check(typeNameOf<Map<int, String>>()).equals('map');
      check(typeNameOf<Map<Object, Object>>()).equals('map');
    });

    test('returns canonical name for List variants', () {
      check(typeNameOf<List<Object?>>()).equals('list');
      check(typeNameOf<List<dynamic>>()).equals('list');
      check(typeNameOf<List<String>>()).equals('list');
      check(typeNameOf<List<int>>()).equals('list');
    });

    test('returns canonical name for primitives', () {
      check(typeNameOf<String>()).equals('string');
      check(typeNameOf<int>()).equals('int');
      check(typeNameOf<double>()).equals('double');
      check(typeNameOf<num>()).equals('number');
      check(typeNameOf<bool>()).equals('bool');
    });

    test('returns toString() for custom and other types', () {
      check(typeNameOf<Object>()).equals('Object');
      check(typeNameOf<Set<String>>()).equals('Set<String>');
      check(typeNameOf<_CustomClass>()).equals('_CustomClass');
    });
  });
}

class _CustomClass {}

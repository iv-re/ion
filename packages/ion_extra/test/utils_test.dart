import 'package:checks/checks.dart';
import 'package:ion_extra/src/utils.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('typeNameOf', () {
    test('returns object for Map variants', () {
      check(typeNameOf<Map<String, Object?>>()).equals('object');
      check(typeNameOf<Map<String, dynamic>>()).equals('object');
      check(typeNameOf<Map<int, String>>()).equals('object');
      check(typeNameOf<Map<Object, Object>>()).equals('object');
    });

    test('returns array for List variants', () {
      check(typeNameOf<List<Object?>>()).equals('array');
      check(typeNameOf<List<dynamic>>()).equals('array');
      check(typeNameOf<List<String>>()).equals('array');
      check(typeNameOf<List<int>>()).equals('array');
    });

    test('returns JSON Schema names for primitives', () {
      check(typeNameOf<String>()).equals('string');
      check(typeNameOf<int>()).equals('integer');
      check(typeNameOf<double>()).equals('number');
      check(typeNameOf<num>()).equals('number');
      check(typeNameOf<bool>()).equals('boolean');
    });

    test('returns toString() for custom and other types', () {
      check(typeNameOf<Object>()).equals('Object');
      check(typeNameOf<Set<String>>()).equals('Set<String>');
      check(typeNameOf<_CustomClass>()).equals('_CustomClass');
    });
  });
}

class _CustomClass {}

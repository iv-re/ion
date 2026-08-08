import 'package:ion_extra/ion_extra.dart';
import 'package:ion_web/ion_web.dart';
import 'package:test/test.dart';

void main() {
  group('RequestQueryExtractor', () {
    test('query parses typed query parameters', () {
      final uri = Uri.parse(
        'http://localhost/items?page=2&limit=20&search=flutter&is_active=true&price=19.99&tags=dart&tags=web',
      );
      final req = _createTestRequestWithUri(uri);

      final filters = req.query(_FiltersDto.fromJson);

      expect(filters.page, equals(2));
      expect(filters.limit, equals(20));
      expect(filters.search, equals('flutter'));
      expect(filters.isActive, isTrue);
      expect(filters.price, equals(19.99));
      expect(filters.tags, equals(['dart', 'web']));
    });

    test(
      'query throws ValidationErrors on type mismatches and rule failures',
      () {
        final uri = Uri.parse(
          'http://localhost/items?page=0&is_active=notabool',
        );
        final req = _createTestRequestWithUri(uri);

        try {
          req.query(_FiltersDto.fromJson);
          fail('Should throw ValidationErrors');
        } on ValidationErrors catch (e) {
          final json = e.toJson();
          expect(json.containsKey('page'), isTrue);
          expect(json.containsKey('is_active'), isTrue);
        }
      },
    );

    test('query respects accumulateValidationErrors = false', () {
      RequestQueryExtractor.accumulateValidationErrors = false;
      addTearDown(
        () => RequestQueryExtractor.accumulateValidationErrors = true,
      );

      final uri = Uri.parse(
        'http://localhost/items?page=0&is_active=notabool',
      );
      final req = _createTestRequestWithUri(uri);

      try {
        req.query(_FiltersDto.fromJson);
        fail('Should throw ValidationErrors');
      } on ValidationErrors catch (e) {
        final errJson = e.toJson();
        expect(errJson.keys, equals(['page']));
      }
    });

    test('query evaluates map lazily on requested keys', () {
      final uri = Uri.parse(
        'http://localhost/items?page=1&unused_param=abc&ignored=123',
      );
      final req = _createTestRequestWithUri(uri);

      final page = req.query((json) => json.integer('page'));
      expect(page, equals(1));
    });

    test('query parses indexed arrays and sorts out-of-order indices', () {
      final uri = Uri.parse(
        'http://localhost/items?user_ids[1]=20&user_ids[0]=10&user_ids[2]=30',
      );
      final req = _createTestRequestWithUri(uri);

      final ids = req.query((json) => json.list<int>('user_ids'));
      expect(ids, equals([10, 20, 30]));
    });

    test('query parses bracket array notation tags[]', () {
      final uri1 = Uri.parse(
        'http://localhost/items?page=1&tags[]=dart&tags[]=flutter',
      );
      final req1 = _createTestRequestWithUri(uri1);

      final filters1 = req1.query(_FiltersDto.fromJson);
      expect(filters1.tags, equals(['dart', 'flutter']));

      final uri2 = Uri.parse('http://localhost/products?category[]=phones');
      final req2 = _createTestRequestWithUri(uri2);

      final category = req2.query((json) => json.list<String>('category'));
      expect(category, equals(['phones']));
    });

    test('query parses nested objects with dot and bracket notation', () {
      final uri1 = Uri.parse(
        'http://localhost/items?filter.search=dart&filter.page=1',
      );
      final req1 = _createTestRequestWithUri(uri1);
      final search1 = req1.query(
        (json) => json.object('filter', _FiltersDto.fromJson).search,
      );
      expect(search1, equals('dart'));

      final uri2 = Uri.parse(
        'http://localhost/items?filter[search]=flutter&filter[page]=2',
      );
      final req2 = _createTestRequestWithUri(uri2);
      final search2 = req2.query(
        (json) => json.object('filter', _FiltersDto.fromJson).search,
      );
      expect(search2, equals('flutter'));

      final uri3 = Uri.parse(
        'http://localhost/items?a[b][c]=42',
      );
      final req3 = _createTestRequestWithUri(uri3);
      final val3 = req3.query(
        (json) {
          return json.object(
            'a',
            (j) => j.object('b', (j2) => j2.integer('c')),
          );
        },
      );
      expect(val3, equals(42));
    });

    test(
      'query parses signed numbers, empty params, and case-insensitive '
      'booleans',
      () {
        final uri = Uri.parse(
          'http://localhost/items?page=-5&price=-12.50&temp=%2B25&q=',
        );
        final req = _createTestRequestWithUri(uri);

        req.query((json) {
          expect(json.integer('page'), equals(-5));
          expect(json.float('price'), equals(-12.50));
          expect(json.integer('temp'), equals(25));
          expect(json.string('q'), equals(''));
        });

        for (final v in ['true', 'TRUE', 'True', 'tRuE']) {
          final u = Uri.parse('http://localhost/items?flag=$v');
          final r = _createTestRequestWithUri(u);
          expect(r.query((json) => json.boolean('flag')), isTrue);
        }

        for (final v in ['false', 'FALSE', 'False', 'fAlSe']) {
          final u = Uri.parse('http://localhost/items?flag=$v');
          final r = _createTestRequestWithUri(u);
          expect(r.query((json) => json.boolean('flag')), isFalse);
        }
      },
    );

    test('query parses typed list of integers', () {
      final uri = Uri.parse('http://localhost/items?ids=10&ids=20&ids=30');
      final req = _createTestRequestWithUri(uri);

      final ids = req.query((json) => json.list<int>('ids'));
      expect(ids, equals([10, 20, 30]));
    });

    test(
      'query supports has checks for direct, bracket, and nested keys',
      () {
        final uri = Uri.parse(
          'http://localhost/items?page=1&tags[]=dart&filter[search]=flutter',
        );
        final req = _createTestRequestWithUri(uri);

        req.query((json) {
          expect(json.has('page'), isTrue);
          expect(json.has('tags'), isTrue);
          expect(json.has('filter'), isTrue);
          expect(json.has('nonexistent'), isFalse);
        });
      },
    );

    test('query allows direct lookup of literal bracket key', () {
      final uri = Uri.parse('http://localhost/items?filter[search]=flutter');
      final req = _createTestRequestWithUri(uri);

      final val = req.query((json) => json.string('filter[search]'));
      expect(val, equals('flutter'));
    });
  });
}

Request _createTestRequestWithUri(Uri uri) {
  return Request(
    const Stream.empty(),
    method: .get,
    uri: uri,
    version: .http11,
    headers: TypedHeaders([]),
  );
}

class _FiltersDto {
  _FiltersDto.fromJson(JsonObject json)
    : page = json.integer('page', rules: [.range(min: 1)]),
      limit = json.integerOrNull('limit') ?? 10,
      search = json.stringOrNull('search'),
      isActive = json.booleanOrNull('is_active'),
      price = json.floatOrNull('price'),
      tags = json.listOrNull<String>('tags') ?? const [];

  final int page;
  final int limit;
  final String? search;
  final bool? isActive;
  final double? price;
  final List<String> tags;
}

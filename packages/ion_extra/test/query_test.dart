import 'package:checks/checks.dart';
import 'package:ion_extra/ion_extra.dart';
import 'package:ion_web/ion_web.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('RequestQueryExtractor', () {
    test('query parses typed query parameters', () {
      final uri = Uri.parse(
        'http://localhost/items?page=2&limit=20&search=flutter&is_active=true&price=19.99&tags=dart&tags=web',
      );
      final req = _createTestRequestWithUri(uri);

      final filters = req.query(_FiltersDto.fromJson);

      check(filters.page).equals(2);
      check(filters.limit).equals(20);
      check(filters.search).equals('flutter');
      check(filters.isActive).equals(true);
      check(filters.price).equals(19.99);
      check(filters.tags).deepEquals(['dart', 'web']);
    });

    test(
      'query throws ValidationErrors on type mismatches and rule failures',
      () {
        final uri = Uri.parse(
          'http://localhost/items?page=0&is_active=notabool',
        );
        final req = _createTestRequestWithUri(uri);

        check(() => req.query(_FiltersDto.fromJson)).throws<ValidationErrors>()
          ..has((e) => e.toJson(), 'toJson').containsKey('page')
          ..has((e) => e.toJson(), 'toJson').containsKey('is_active');
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

      check(() => req.query(_FiltersDto.fromJson))
          .throws<ValidationErrors>()
          .has((e) => e.toJson().keys, 'keys')
          .deepEquals(['page']);
    });

    test('query evaluates map lazily on requested keys', () {
      final uri = Uri.parse(
        'http://localhost/items?page=1&unused_param=abc&ignored=123',
      );
      final req = _createTestRequestWithUri(uri);

      final page = req.query((json) => json.integer('page'));
      check(page).equals(1);
    });

    test('query parses indexed arrays and sorts out-of-order indices', () {
      final uri = Uri.parse(
        'http://localhost/items?user_ids[1]=20&user_ids[0]=10&user_ids[2]=30',
      );
      final req = _createTestRequestWithUri(uri);

      final ids = req.query((json) => json.list<int>('user_ids'));
      check(ids).deepEquals([10, 20, 30]);
    });

    test('query parses bracket array notation tags[]', () {
      final uri1 = Uri.parse(
        'http://localhost/items?page=1&tags[]=dart&tags[]=flutter',
      );
      final req1 = _createTestRequestWithUri(uri1);

      final filters1 = req1.query(_FiltersDto.fromJson);
      check(filters1.tags).deepEquals(['dart', 'flutter']);

      final uri2 = Uri.parse('http://localhost/products?category[]=phones');
      final req2 = _createTestRequestWithUri(uri2);

      final category = req2.query((json) => json.list<String>('category'));
      check(category).deepEquals(['phones']);
    });

    test('query parses nested objects with dot and bracket notation', () {
      final uri1 = Uri.parse(
        'http://localhost/items?filter.search=dart&filter.page=1',
      );
      final req1 = _createTestRequestWithUri(uri1);
      final search1 = req1.query(
        (json) => json.object('filter', _FiltersDto.fromJson).search,
      );
      check(search1).equals('dart');

      final uri2 = Uri.parse(
        'http://localhost/items?filter[search]=flutter&filter[page]=2',
      );
      final req2 = _createTestRequestWithUri(uri2);
      final search2 = req2.query(
        (json) => json.object('filter', _FiltersDto.fromJson).search,
      );
      check(search2).equals('flutter');

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
      check(val3).equals(42);
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
          check(json.integer('page')).equals(-5);
          check(json.float('price')).equals(-12.50);
          check(json.integer('temp')).equals(25);
          check(json.string('q')).equals('');
        });

        for (final v in ['true', 'TRUE', 'True', 'tRuE']) {
          final u = Uri.parse('http://localhost/items?flag=$v');
          final r = _createTestRequestWithUri(u);
          check(r.query((json) => json.boolean('flag'))).isTrue();
        }

        for (final v in ['false', 'FALSE', 'False', 'fAlSe']) {
          final u = Uri.parse('http://localhost/items?flag=$v');
          final r = _createTestRequestWithUri(u);
          check(r.query((json) => json.boolean('flag'))).isFalse();
        }
      },
    );

    test('query parses typed list of integers', () {
      final uri = Uri.parse('http://localhost/items?ids=10&ids=20&ids=30');
      final req = _createTestRequestWithUri(uri);

      final ids = req.query((json) => json.list<int>('ids'));
      check(ids).deepEquals([10, 20, 30]);
    });

    test(
      'query supports has checks for direct, bracket, and nested keys',
      () {
        final uri = Uri.parse(
          'http://localhost/items?page=1&tags[]=dart&filter[search]=flutter',
        );
        final req = _createTestRequestWithUri(uri);

        req.query((json) {
          check(json.has('page')).isTrue();
          check(json.has('tags')).isTrue();
          check(json.has('filter')).isTrue();
          check(json.has('nonexistent')).isFalse();
        });
      },
    );

    test('query allows direct lookup of literal bracket key', () {
      final uri = Uri.parse('http://localhost/items?filter[search]=flutter');
      final req = _createTestRequestWithUri(uri);

      final val = req.query((json) => json.string('filter[search]'));
      check(val).equals('flutter');
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

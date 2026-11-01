import 'package:checks/checks.dart';
import 'package:ion_extra/ion_extra.dart';
import 'package:ion_web/ion_web.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('RequestQueryExtractor', () {
    test('parses typed query parameters', () {
      final filters = _query(
        'page=2&limit=20&search=flutter&is_active=true&price=19.99'
        '&tags=dart&tags=web',
      ).query(_FiltersDto.fromJson);

      check(filters.page).equals(2);
      check(filters.limit).equals(20);
      check(filters.search).equals('flutter');
      check(filters.isActive).equals(true);
      check(filters.price).equals(19.99);
      check(filters.tags).deepEquals(['dart', 'web']);
    });

    test('converts values only to the type a getter asks for', () {
      _query('phone=%2B79991234567&zip=007&q=true&n=10&price=-12.50').query((
        json,
      ) {
        check(json.string('phone')).equals('+79991234567');
        check(json.string('zip')).equals('007');
        check(json.string('q')).equals('true');
        check(json.string('n')).equals('10');
        check(json.int('n')).equals(10);
        check(json.double('n')).equals(10);
        check(json.double('price')).equals(-12.5);
      });
    });

    test('collects type mismatches and rule failures', () {
      check(
        () => _query('page=0&is_active=notabool').query(_FiltersDto.fromJson),
      ).throwsCodes().deepEquals({
        'page': ['range'],
        'is_active': ['type'],
      });
    });

    test('with failFast throws on the first error', () {
      check(
        () => _query(
          'page=0&is_active=notabool',
        ).query(_FiltersDto.fromJson, failFast: true),
      ).throwsCodes().deepEquals({
        'page': ['range'],
      });
    });

    test('treats empty values as absent except for strings', () {
      _query('topic_id=&q=').query((json) {
        check(json.intOrNull('topic_id')).isNull();
        check(json.string('q')).equals('');
      });
      check(
        () => _query('topic_id=').query((json) => json.int('topic_id')),
      ).throwsCodes().deepEquals({
        'topic_id': ['required'],
      });
    });

    group('lists', () {
      test('accept a single value', () {
        check(
          _query('note_ids=5').query((json) => json.list('note_ids', .int)),
        ).deepEquals([5]);
      });

      test('join repeated and bracket keys', () {
        check(
          _query('ids=1&ids[]=2&ids=3').query((json) => json.list('ids', .int)),
        ).deepEquals([1, 2, 3]);
        check(
          _query('category[]=phones').query(
            (json) => json.list('category', .string),
          ),
        ).deepEquals(['phones']);
      });

      test('order indexed items by index', () {
        check(
          _query(
            'user_ids[1]=20&user_ids[0]=10&user_ids[2]=30',
          ).query((json) => json.list('user_ids', .int)),
        ).deepEquals([10, 20, 30]);
      });

      test('hold indexed objects', () {
        final items = _query(
          'items[1][id]=2&items[0][id]=1&items[0][name]=a&items[1][name]=b',
        ).query((json) => json.list('items', .object(_ItemDto.fromJson)));

        check([for (final item in items) (item.id, item.name)]).deepEquals([
          (1, 'a'),
          (2, 'b'),
        ]);
      });

      test('report item errors at the item path', () {
        check(
          () => _query('ids=1&ids=x').query((json) => json.list('ids', .int)),
        ).throwsCodes().deepEquals({
          'ids.1': ['type'],
        });
      });
    });

    test('nests objects with dot and bracket notation', () {
      for (final query in [
        'filter.search=dart&filter.page=1',
        'filter[search]=dart&filter[page]=1',
        'filter.search=dart&filter[page]=1',
      ]) {
        final filter = _query(
          query,
        ).query((json) => json.object('filter', _FiltersDto.fromJson));
        check(filter.search).equals('dart');
        check(filter.page).equals(1);
      }

      check(
        _query('a[b][c]=42').query(
          (json) => json.object('a', (j) => j.object('b', (j) => j.int('c'))),
        ),
      ).equals(42);
    });

    test('reports nested errors at the nested path', () {
      check(
        () => _query(
          'filter[page]=x',
        ).query((json) => json.object('filter', _FiltersDto.fromJson)),
      ).throwsCodes().deepEquals({
        'filter.page': ['type'],
      });
    });

    test('exposes normalized keys', () {
      _query('page=1&tags[]=dart&filter[search]=flutter&filter.page=2').query((
        json,
      ) {
        check(json.keys).deepEquals(['page', 'tags', 'filter']);
        check(json.has('filter')).isTrue();
        check(json.has('filter[search]')).isFalse();
        check(json.has('nonexistent')).isFalse();
        check(json.object('filter', (j) => j.keys)).deepEquals([
          'search',
          'page',
        ]);
      });
    });

    test('gives read-only values to raw reads', () {
      final (repeated, indexed, nested) = _query(
        'b=2&b=3&c[0]=x&d[e]=y',
      ).query((json) => (json.any('b'), json.any('c'), json.any('d')));

      check(() => (repeated as List<Object?>).add('4')).throws<Object>();
      check(() => (indexed as List<Object?>).add('z')).throws<Object>();
      check(
        () => (nested as Map<String, Object?>)['f'] = 'z',
      ).throws<Object>();
    });
  });
}

Request _query(String query) => Request(
  const Stream.empty(),
  method: .get,
  uri: .parse('http://localhost/items?$query'),
  version: .http11,
  headers: TypedHeaders([]),
);

extension on Subject<Object? Function()> {
  Subject<Map<String, List<String>>> throwsCodes() =>
      throws<ValidationErrors>().has(
        (e) => {
          for (final MapEntry(:key, :value) in e.errors.entries)
            key: [for (final error in value) error.code],
        },
        'error codes',
      );
}

class _FiltersDto {
  _FiltersDto.fromJson(JsonObject json)
    : page = json.int('page', rules: [.range(min: 1)]),
      limit = json.intOrNull('limit') ?? 10,
      search = json.stringOrNull('search'),
      isActive = json.boolOrNull('is_active'),
      price = json.doubleOrNull('price'),
      tags = json.listOrNull('tags', .string) ?? const [];

  final int page;
  final int limit;
  final String? search;
  final bool? isActive;
  final double? price;
  final List<String> tags;
}

class _ItemDto {
  _ItemDto.fromJson(JsonObject json)
    : id = json.int('id'),
      name = json.string('name');

  final int id;
  final String name;
}

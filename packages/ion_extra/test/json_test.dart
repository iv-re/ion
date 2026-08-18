import 'dart:convert';
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:ion_extra/ion_extra.dart';
import 'package:ion_web/ion_web.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Json, JsonList & RawJson Responses', () {
    test('JsonList serializes list of ToJson items', () {
      final response = JsonList([
        _ItemDto(title: 'Item A'),
        _ItemDto(title: 'Item B'),
      ]);

      check(response.status).equals(HttpStatusCode.ok);
    });

    test('Json serializes single ToJson item', () {
      final response = Json(_ItemDto(title: 'Item A'));

      check(response.status).equals(HttpStatusCode.ok);
    });

    test('Json and JsonList accept custom headers', () {
      final response1 = Json(
        _ItemDto(title: 'Item A'),
        headers: [const .contentType('application/json')],
      );
      check(response1.headers).length.equals(2);

      final response2 = JsonList(
        [_ItemDto(title: 'Item A')],
        headers: [const .contentType('application/json')],
      );
      check(response2.headers).length.equals(2);
    });

    test('RawJson serializes payload and sets application/json header', () {
      final res1 = RawJson({'key': 'value'});
      check(res1.headers).contains(
        const TypedHeader.contentType('application/json'),
      );
      final bytes1 = (res1.body as BytesResponseBody).bytes;
      check(utf8.decode(bytes1)).equals('{"key":"value"}');

      final res2 = RawJson([1, 2, 3]);
      final bytes2 = (res2.body as BytesResponseBody).bytes;
      check(utf8.decode(bytes2)).equals('[1,2,3]');
    });
  });

  group('RequestJsonExtractor', () {
    test('json respects accumulateValidationErrors = false', () async {
      RequestJsonExtractor.accumulateValidationErrors = false;
      addTearDown(() => RequestJsonExtractor.accumulateValidationErrors = true);

      final jsonBytes = utf8.encode('{"username": "usr", "email": "invalid"}');
      final req = _createTestRequest(jsonBytes);

      // Since it fails fast, it should only contain 'username' (the first
      // checked field). 'email' and 'age' won't be evaluated.
      await check(
        req.json(
          (j) => _UserDto(
            username: j.string('username', rules: [.length(min: 5)]),
            email: j.string('email', rules: [.email()]),
            age: j.integer('age'),
          ),
        ),
      ).throws<ValidationErrors>(
        (it) => it.has((e) => e.toJson().keys, 'keys').deepEquals(['username']),
      );
    });

    test('jsonList respects accumulateValidationErrors = false', () async {
      RequestJsonExtractor.accumulateValidationErrors = false;
      addTearDown(() => RequestJsonExtractor.accumulateValidationErrors = true);

      final jsonBytes = utf8.encode('[{"title": ""}, {"title": ""}]');
      final req = _createTestRequest(jsonBytes);

      // Since it fails fast, it should only contain the error for the
      // first index.
      await check(
        req.jsonList<_ItemDto>(
          (j) => _ItemDto(title: j.string('title', rules: [.length(min: 1)])),
        ),
      ).throws<ValidationErrors>(
        (it) =>
            it.has((e) => e.toJson().keys, 'keys').deepEquals([r'$.0.title']),
      );
    });

    test('jsonList parses top-level JSON array of objects', () async {
      final jsonBytes = utf8.encode(
        '[{"title": "Item 1"}, {"title": "Item 2"}]',
      );
      final req = _createTestRequest(jsonBytes);

      final items = await req.jsonList(_ItemDto.fromJson);
      check(items)
        ..length.equals(2)
        ..has((it) => it[0].title, 'items[0].title').equals('Item 1')
        ..has((it) => it[1].title, 'items[1].title').equals('Item 2');
    });

    test('jsonList parses top-level JSON array of primitive strings', () async {
      final jsonBytes = utf8.encode('["apple", "banana"]');
      final req = _createTestRequest(jsonBytes);

      final items = await req.jsonList<String>();
      check(items).deepEquals(['apple', 'banana']);
    });

    test(
      'jsonList throws ValidationErrors when top-level JSON is not a list',
      () async {
        final jsonBytes = utf8.encode('{"title": "Not a list"}');
        final req = _createTestRequest(jsonBytes);

        await check(
          req.jsonList(_ItemDto.fromJson),
        ).throws<ValidationErrors>(
          (it) => it.has((e) => e.toJson(), 'toJson').containsKey(r'$'),
        );
      },
    );

    test(
      'json throws ValidationErrors when top-level JSON is not an object',
      () async {
        final jsonBytes = utf8.encode('[1, 2, 3]');
        final req = _createTestRequest(jsonBytes);

        await check(
          req.json((json) => json.string('title')),
        ).throws<ValidationErrors>(
          (it) => it.has((e) => e.toJson(), 'toJson').containsKey(r'$'),
        );
      },
    );

    test('json throws invalid_json for empty request', () async {
      final req = _createTestRequest([]);

      await check(
        req.json((json) => json.string('title')),
      ).throws<ValidationErrors>(
        (it) => it
            .has((e) => e.errors[r'$'], 'root errors')
            .isNotNull()
            .deepEquals([const ValidationError(code: 'invalid_json')]),
      );
    });

    test('rawJson decodes raw JSON map, list, and primitives', () async {
      final req1 = _createTestRequest(utf8.encode('{"foo": "bar", "num": 42}'));
      final raw1 = await req1.rawJson<Map<String, Object?>>();
      check(raw1).deepEquals({'foo': 'bar', 'num': 42});

      final req2 = _createTestRequest(utf8.encode('[1, 2, "three"]'));
      final raw2 = await req2.rawJson<List<Object?>>();
      check(raw2).deepEquals([1, 2, 'three']);

      final req3 = _createTestRequest(utf8.encode('"hello"'));
      final raw3 = await req3.rawJson<Object?>();
      check(raw3).equals('hello');
    });

    test(
      'rawJson throws ValidationErrors with correct map/list expected types on mismatch',
      () async {
        final req1 = _createTestRequest(utf8.encode('[1, 2, 3]'));
        await check(
          req1.rawJson<Map<String, Object?>>(),
        ).throws<ValidationErrors>(
          (it) =>
              it.has((e) => e.errors[r'$']?.first, 'first error').isNotNull()
                ..has((err) => err.code, 'code').equals('type')
                ..has((err) => err.params['expected'], 'expected').equals('map')
                ..has((err) => err.params['actual'], 'actual').equals('list'),
        );

        final req2 = _createTestRequest(utf8.encode('{"foo": "bar"}'));
        await check(
          req2.rawJson<List<Object?>>(),
        ).throws<ValidationErrors>(
          (it) =>
              it.has((e) => e.errors[r'$']?.first, 'first error').isNotNull()
                ..has((err) => err.code, 'code').equals('type')
                ..has(
                  (err) => err.params['expected'],
                  'expected',
                ).equals('list')
                ..has((err) => err.params['actual'], 'actual').equals('map'),
        );
      },
    );

    test('rawJson throws invalid_json for malformed JSON', () async {
      final req = _createTestRequest(utf8.encode('{ invalid }'));
      await check(
        req.rawJson<Object?>(),
      ).throws<ValidationErrors>(
        (it) => it
            .has((e) => e.errors[r'$'], 'root errors')
            .isNotNull()
            .deepEquals([const ValidationError(code: 'invalid_json')]),
      );
    });
  });
}

Request _createTestRequest(List<int> bodyBytes) {
  final stream = Stream.value(Uint8List.fromList(bodyBytes));
  return Request(
    stream,
    method: .post,
    uri: .parse('http://localhost/'),
    version: .http11,
    headers: TypedHeaders([]),
  );
}

class _UserDto {
  _UserDto({
    required this.username,
    required this.email,
    required this.age,
  });

  final String username;
  final String email;
  final int age;
}

class _ItemDto implements ToJson {
  _ItemDto({required this.title});

  _ItemDto.fromJson(JsonObject json) : title = json.string('title');

  final String title;

  @override
  Map<String, Object?> toJson() => {'title': title};
}

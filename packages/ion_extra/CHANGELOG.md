## 0.3.0

- **Breaking:** upgrade `json_codable` to `^0.3.0`. Getters are named after Dart
  types (`json.int`, `json.double`, `json.bool`) and collections take an item
  type (`json.list('ids', .int)`).
- **Breaking:** `req.query()` keeps values as strings and converts them when a
  getter asks for a type, instead of guessing types up front. `?zip=007` reads
  as `'007'`, `?phone=+7999...` stays a string, and `?n=10` reads with both
  `json.int` and `json.double`. Booleans must be `true` or `false`, and
  integers must not have a `+` sign.
- **Breaking:** `req.jsonList()` takes a `JsonType` for its items, such as
  `req.jsonList(.object(ItemDto.fromJson))` or `req.jsonList(.string)`.
- **Breaking:** replace the static `accumulateValidationErrors` flags of
  `RequestJsonExtractor` and `RequestQueryExtractor` with a `failFast`
  parameter on `json()`, `jsonList()` and `query()`.
- **Breaking:** `rawJson()` type errors name types like JSON Schema: `integer`,
  `number`, `boolean`, `object`, `array`.
- **Breaking:** query keys are normalized: `json.keys` lists `tags` and
  `filter` for `?tags[]=a&filter[page]=1`, and literal keys such as
  `filter[page]` can no longer be read directly.
- Query values: an empty value counts as absent except for strings, a single
  value is accepted where a list is expected, `ids` and `ids[]` are joined in
  order, and indexed lists of objects such as `items[0][id]=1` are supported.
- Query maps and lists are read-only.

## 0.2.0

- Upgraded `json_codable` to `^0.2.0`.

## 0.1.0

- Initial version.

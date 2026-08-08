# ion_extra

JSON parsing, validation, and schema utilities for `ion_web`.

## Usage

### Typed JSON Parsing & Validation (via `json_codable`)

Use `JsonObject` to extract/validate request bodies and implement `ToJson` for response DTOs:

```dart
import 'package:ion_extra/ion_extra.dart';

class CreateUserDto {
  CreateUserDto.fromJson(JsonObject json)
      : name = json.string('name', rules: [.length(min: 2)]),
        email = json.string('email', rules: [.email()]),
        age = json.integerOrNull('age', rules: [.range(min: 18)]);

  final String name;
  final String email;
  final int? age;
}

class UserDto implements ToJson {
  UserDto({required this.id, required this.name});

  final String id;
  final String name;

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
  };
}
```

### Parsing Query Parameters

Extract and validate URL query parameters into domain models with `req.query()`:

```dart
class UserFilters {
  UserFilters.fromJson(JsonObject json)
      : page = json.integer('page', rules: [.range(min: 1)]),
        search = json.stringOrNull('search'),
        tags = json.listOrNull<String>('tags') ?? const [];

  final int page;
  final String? search;
  final List<String> tags;
}

// Extract query parameters from URL: /users?page=1&search=alice&tags=dart&tags=flutter
app.get('/users', (req) {
  final filters = req.query(UserFilters.fromJson);
  return JsonList(findUsers(filters));
});
```

Query parsing supports:
- Automatic type conversion (`int`, `double`, `bool`, `String`).
- Multiple array notations: `?tags=a&tags=b` and HTML `?tags[]=a&tags[]=b`.
- Nested DTO objects: `?filter.search=alice` or `?filter[search]=alice`.

### Parsing JSON Requests & Responses

Parse request bodies directly with `req.json()` and return responses with `Json` (for `ToJson` instances) or `Json.raw` (for raw maps):

```dart
// Pass models implementing ToJson to Json() or JsonList()
app.get('/users/{id}', (req) => Json(userDto));

// Pass raw maps, lists, or primitives to RawJson()
app.post('/users', (req) async {
  final payload = await req.json(CreateUserDto.fromJson);

  return RawJson({'id': '123', 'name': payload.name}, status: .created);
});
```

### Validation Error Handling

Catch `ValidationErrors` in middleware to automatically return validation failure details:

```dart
app.use((next) => (req) async {
  try {
    return await next(req);
  } on ValidationErrors catch (error) {
    return Json(error, status: .badRequest);
  }
});
```

### Schema Generation

Generate OpenAPI and JSON Schema documents directly from `fromJson` constructors or builder callbacks:

```dart
class CreateUserDto {
  // ...
  static final Schema schema = JsonObject.schema(
    CreateUserDto.fromJson,
    title: 'CreateUserDto',
  );
}
```

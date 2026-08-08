# ion_openapi

OpenAPI 3.x specification generator for `ion_router` applications.

## Usage

Attach `ApiOperation` metadata to your routes and generate the OpenAPI document using `OpenApi.fromRouter`:

```dart
import 'package:ion_openapi/ion_openapi.dart';
import 'package:ion_router/ion_router.dart';
import 'package:ion_web/ion_web.dart';

final app = Router();

app.get(
  '/todos',
  _getTodos,
  meta: [
    const ApiOperation(
      summary: 'Get all todos',
      responses: {
        .ok: .json(TodoDto.schema, description: 'List of todo items'),
      },
    ),
  ],
);

app.get('/openapi.json', (_) {
  final openApi = OpenApi.fromRouter(
    app,
    info: const OpenApiInfo(title: 'Todos API', version: '1.0'),
  );
  return Json(openApi);
});
```

> **Note:** Schemas can be generated directly from your DTOs using `JsonObject.schema` provided by `ion_extra`.

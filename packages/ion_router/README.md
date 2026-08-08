# ion_router

HTTP router for `ion_web`.

## Usage

### Basic Routing

```dart
import 'package:ion_router/ion_router.dart';
import 'package:ion_web/ion_web.dart';

final app = Router();

app.get('/', (req) => .text('Hello World'));
app.post('/items', (req) => .text('Item created'));
app.all('/any', (req) => .text('Matches any HTTP method'));
```

### Route Parameters & Wildcards

```dart
// Named parameters
app.get('/users/{userId}', (req) {
  final userId = req.param('userId');
  return .text('User ID: $userId');
});

// Wildcard matching
app.get('/files/*', (req) {
  final path = req.param('*');
  return .text('File path: $path');
});
```

### Middleware

Add middleware globally using `use`:

```dart
app.use((next) => (req) async {
  print('${req.method} ${req.uri.path}');
  return await next(req);
});
```

### Groups & `withMiddleware`

Group routes or apply scoped middleware using `group` or `withMiddleware`:

```dart
// Inline group with shared middleware
app.group((r) {
  r.use(authMiddleware);

  r.get('/profile', (req) => .text('Profile'));
  r.get('/settings', (req) => .text('Settings'));
});

// Inline router with additional middleware
final admin = app.withMiddleware(adminGuard);
admin.get('/admin/dashboard', (req) => .text('Admin Dashboard'));
```

### Sub-routing & Mounting

Mount sub-routers with path prefixes using `route` or `mount`:

```dart
// Sub-router with prefixed path (/api/v1/...)
app.route('/api/v1', (api) {
  api.get('/users', (req) => .text('Users list'));
  api.get('/posts', (req) => .text('Posts list'));
});

// Mount an external handler/router onto a path prefix
app.mount('/static', staticFileHandler);
```

### Custom 404 & 405 Handlers

Handle `404 Not Found` and `405 Method Not Allowed` responses with custom logic:

```dart
app.notFound((req) {
  return .text('Custom 404 Page Not Found', status: .notFound);
});

app.methodNotAllowed((req) {
  return .text('Custom 405 Method Not Allowed', status: .methodNotAllowed);
});
```

### Route Introspection & Metadata

Attach metadata objects to routes and inspect registered routes programmatically:

```dart
// Attach metadata to a route
app.get(
  '/users',
  _getUsers,
  meta: [
    const ApiOperation(summary: 'List users'),
    const AuthRequired(),
  ],
);

// Inspect registered routes and retrieve metadata by type
for (final route in app.routes()) {
  print('${route.method?.value ?? 'ALL'} ${route.pattern}');
  final operation = route.metaOf<ApiOperation>();
}

// Walk all routes including nested sub-routers
app.walk((method, fullPath, middlewares, meta) {
  print('${method.value} $fullPath (metadata: $meta)');
});

// Match routes without running the handler
final matched = app.match(.get, '/users/123'); // true
final pattern = app.find(.get, '/users/123');  // '/users/{userId}'
```

`ion_openapi` uses route metadata and introspection to generate OpenAPI specifications.

## Acknowledgements

Inspired by Go's [`chi`](https://github.com/go-chi/chi) router (`go-chi/chi`).

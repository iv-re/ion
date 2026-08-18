# Ion

> Modular HTTP framework ecosystem for Dart

<p align="center">
  <a href="https://docs.page/iv-re/ion"><img src="https://img.shields.io/badge/docs-docs.page-blue" alt="docs" /></a>
</p>

**Ion** is a set of decoupled, composable packages for building HTTP servers, REST APIs, and realtime services in Dart.

- **Type safety** — strongly-typed headers, request context, and response builders throughout
- **Performance** — HTTP/1.1 server built on raw TCP sockets with keep-alive and configurable timeouts
- **Modularity** — use `ion_web` standalone or adopt any combination of packages; no required scaffolding

## Basic Example

```dart
import 'package:ion_router/ion_router.dart';
import 'package:ion_web/ion_web.dart';

Future<void> main() async {
  final app = Router();

  app.get('/', (req) => .text('Welcome to ion'));
  app.get('/hello/{name}', (req) => .text('Hello, ${req.param('name')}!'));

  final server = await IonServer.serve(
    app,
    address: .loopbackIPv4,
    port: 8080,
  );

  print('Server listening on http://${server.address.host}:${server.port}');
}
```

## The Ecosystem

Choose only the components you need. Every package is designed to work independently or together.

| Package | Description | Version |
| --- | --- | --- |
| [`ion_web`](./packages/ion_web) | HTTP/1.1 socket server, request parsing, response builders, WebSockets, SSE, and multipart uploads. | [![Pub Version](https://img.shields.io/pub/v/ion_web)](https://pub.dev/packages/ion_web) |
| [`ion_router`](./packages/ion_router) | Router with path parameters, middleware pipelines, route groups, and tree introspection. | [![Pub Version](https://img.shields.io/pub/v/ion_router)](https://pub.dev/packages/ion_router) |
| [`ion_openapi`](./packages/ion_openapi) | OpenAPI 3.x spec generator — no code generation required. | [![Pub Version](https://img.shields.io/pub/v/ion_openapi)](https://pub.dev/packages/ion_openapi) |
| [`ion_extra`](./packages/ion_extra) | Typed JSON parsing, query parameter decoding, field validation, and schema generation. | [![Pub Version](https://img.shields.io/pub/v/ion_extra)](https://pub.dev/packages/ion_extra) |
| [`ion_test`](./packages/ion_test) | In-process test client and declarative test runner for handlers. | [![Pub Version](https://img.shields.io/pub/v/ion_test)](https://pub.dev/packages/ion_test) |
| [`ion_hotreload`](./packages/ion_hotreload) | Hot reload for development — rebuilds the handler without dropping active connections. | [![Pub Version](https://img.shields.io/pub/v/ion_hotreload)](https://pub.dev/packages/ion_hotreload) |

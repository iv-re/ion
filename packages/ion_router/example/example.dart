import 'package:ion_router/ion_router.dart';
import 'package:ion_web/ion_web.dart';

void main() async {
  final app = Router();

  // Standard Middlewares
  app.use(Middlewares.requestId());
  app.use(Middlewares.cors(.allowAll()));
  app.use(Middlewares.errorHandler());

  // Basic Routes & HTTP Methods
  app.get('/', (req) {
    final reqId = req.ctx.requestId ?? 'none';
    return .text('Hello from ion_router! Request-ID: $reqId');
  });

  app.post('/echo', (req) async {
    final body = await req.text();
    return .text('Echo: $body');
  });

  //  Path Parameters & Typed Parsing
  app.get('/users/{id}', (req) {
    final userId = req.parseParam('id', int.tryParse);
    if (userId == null) {
      return .text('Invalid User ID', status: .badRequest);
    }
    return .text('User Profile for ID: $userId');
  });

  // Wildcard Route Matching
  app.get('/static/*', (req) {
    final filePath = req.param('*');
    return .text('Serving static file: $filePath');
  });

  // Grouping with Scoped Middleware (e.g. Basic Auth)
  app.group((router) {
    router.use(
      Middlewares.basicAuth(
        credentials: {'admin': 'secret'},
      ),
    );

    router.get('/admin/dashboard', (req) => .text('Protected Admin Dashboard'));
    router.get('/admin/settings', (req) => .text('Protected Admin Settings'));
  });

  // Sub-routing with Path Prefixes
  app.route('/api/v1', (api) {
    api.get('/status', (req) => .text('API v1 operational'));
    api.get('/items/{itemId}', (req) {
      final itemId = req.param('itemId');
      return .text('Item details for #$itemId');
    });
  });

  // Standalone Router Merging
  final metricsRouter = Router()
    ..get('/metrics', (req) => .text('System Metrics: OK'));

  app.merge(metricsRouter);

  // Custom 404 & 405 Handlers
  app.notFound((req) {
    return .text('Custom 404: Route not found', status: .notFound);
  });

  app.methodNotAllowed((req) {
    return .text('Custom 405: Method not allowed', status: .methodNotAllowed);
  });

  // Route Introspection & Metadata
  app.get(
    '/routes',
    (req) {
      final buf = StringBuffer('Registered Routes:\n');
      app.walk((method, fullRoute, middlewares, meta) {
        buf.writeln('${method.value.padRight(7)} $fullRoute (metadata: $meta)');
      });
      return .text(buf.toString());
    },
    meta: [const RouteTag('introspection')],
  );

  final server = await IonServer.serve(
    app.call,
    address: .loopbackIPv4,
    port: 8080,
  );

  print('Server listening on http://${server.address.host}:${server.port}');
}

final class RouteTag {
  const RouteTag(this.name);

  final String name;

  @override
  String toString() => 'RouteTag($name)';
}

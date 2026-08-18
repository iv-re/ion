import 'package:checks/checks.dart';
import 'package:ion_router/ion_router.dart';
import 'package:ion_web/ion_web.dart';
import 'package:test/scaffolding.dart';

Future<Response> req(
  Router app,
  HttpMethod method,
  String path, {
  Iterable<TypedHeader>? headers,
}) async {
  return app(
    Request(
      const Stream.empty(),
      method: method,
      uri: Uri.parse('http://localhost$path'),
      version: .http11,
      headers: TypedHeaders.fromList(headers ?? const []),
    ),
  );
}

extension on Response {
  String get bodyText {
    if (body case BytesResponseBody(:final bytes)) {
      return String.fromCharCodes(bytes);
    }
    return '';
  }

  String? header(String key) {
    for (final h in headers) {
      if (h.name.toLowerCase() == key.toLowerCase()) return h.value;
    }
    return null;
  }
}

void main() {
  group('Router Matching', () {
    test('matches static, overlapping param, and extension routes', () async {
      final app = Router()
        ..get('/', (req) => Response.text('index'))
        ..get('/favicon.ico', (req) => Response.text('favicon'))
        ..get('/pages/*', (req) => Response.text('page:${req.param('*')}'))
        ..get('/article', (req) => Response.text('article list'))
        ..get('/article/near', (req) => Response.text('article near'))
        ..get(
          '/article/{id}',
          (req) => Response.text('article:${req.param('id')}'),
        )
        ..get(
          '/article/{id}/{opts}',
          (req) => Response.text(
            'opts:${req.param('id')}/${req.param('opts')}',
          ),
        )
        ..get(
          '/article/slug/{month}/-/{day}/{year}',
          (req) => Response.text(
            'slug:${req.param('month')}/${req.param('day')}/${req.param('year')}',
          ),
        )
        ..get(
          '/articles/{file}.{ext}',
          (req) => Response.text(
            'file:${req.param('file')}.${req.param('ext')}',
          ),
        );

      check((await req(app, .get, '/')).bodyText).equals('index');
      check((await req(app, .get, '/favicon.ico')).bodyText).equals('favicon');

      // Overlapping static vs param (/article/near vs /article/123)
      check(
        (await req(app, .get, '/article/near')).bodyText,
      ).equals('article near');
      check(
        (await req(app, .get, '/article/123')).bodyText,
      ).equals('article:123');

      // Multiple parameters
      check(
        (await req(app, .get, '/article/123/456')).bodyText,
      ).equals('opts:123/456');
      check(
        (await req(app, .get, '/article/slug/sept/-/4/2015')).bodyText,
      ).equals('slug:sept/4/2015');

      // Extension / Delimiter parameters
      check(
        (await req(app, .get, '/articles/doc.pdf')).bodyText,
      ).equals('file:doc.pdf');
    });

    test('overwrites route when registering duplicate pattern', () async {
      final app = Router()
        ..get('/ping/{id}', (req) => Response.text('first:${req.param('id')}'))
        ..get(
          '/ping/{id}',
          (req) => Response.text('second:${req.param('id')}'),
        );

      final res = await req(app, .get, '/ping/123');
      check(res.bodyText).equals('second:123');
    });
  });

  group('Router Static Routes', () {
    test('matches GET and POST static routes', () async {
      final app = Router()
        ..get('/', (req) => Response.text('root'))
        ..get('/hello', (req) => Response.text('get hello'))
        ..post('/hello', (req) => Response.text('post hello'));

      check((await req(app, .get, '/')).status).equals(HttpStatusCode.ok);
      check((await req(app, .get, '/hello')).status).equals(HttpStatusCode.ok);
      check((await req(app, .post, '/hello')).status).equals(HttpStatusCode.ok);
    });
  });

  group('Router HTTP Methods', () {
    test('supports all HTTP method shortcuts', () async {
      final app = Router()
        ..get('/test', (req) => Response.text('get'))
        ..post('/test', (req) => Response.text('post'))
        ..put('/test', (req) => Response.text('put'))
        ..delete('/test', (req) => Response.text('delete'))
        ..patch('/test', (req) => Response.text('patch'))
        ..head('/test', (req) => Response.text('head'))
        ..options('/test', (req) => Response.text('options'))
        ..connect('/test', (req) => Response.text('connect'))
        ..trace('/test', (req) => Response.text('trace'))
        ..query('/test', (req) => Response.text('query'))
        ..all('/any', (req) => Response.text('all'));

      check((await req(app, .put, '/test')).status).equals(HttpStatusCode.ok);
      check(
        (await req(app, .delete, '/test')).status,
      ).equals(HttpStatusCode.ok);
      check((await req(app, .patch, '/test')).status).equals(HttpStatusCode.ok);
      check((await req(app, .head, '/test')).status).equals(HttpStatusCode.ok);
      check(
        (await req(app, .options, '/test')).status,
      ).equals(HttpStatusCode.ok);
      check(
        (await req(app, .connect, '/test')).status,
      ).equals(HttpStatusCode.ok);
      check((await req(app, .trace, '/test')).status).equals(HttpStatusCode.ok);
      check((await req(app, .query, '/test')).status).equals(HttpStatusCode.ok);

      check((await req(app, .get, '/any')).status).equals(HttpStatusCode.ok);
      check((await req(app, .post, '/any')).status).equals(HttpStatusCode.ok);
    });
  });

  group('Router Parameters', () {
    test('extracts path parameters correctly', () async {
      final app = Router()
        ..get('/users/{id}', (req) {
          final id = req.param('id');
          return Response.text('user:$id');
        })
        ..get('/orgs/{orgId}/members/{memberId}', (req) {
          final orgId = req.param('orgId');
          final memberId = req.param('memberId');
          return Response.text('org:$orgId,member:$memberId');
        });

      check(
        (await req(app, .get, '/users/123')).status,
      ).equals(HttpStatusCode.ok);
      check(
        (await req(app, .get, '/orgs/pusk/members/salvatore')).status,
      ).equals(HttpStatusCode.ok);
    });
  });

  group('Router Wildcards', () {
    test('matches catch-all wildcards', () async {
      final app = Router()
        ..get('/static/*', (req) {
          final filepath = req.param('*');
          return Response.text('file:$filepath');
        });

      final res = await req(app, .get, '/static/css/main.css');
      check(res.status).equals(HttpStatusCode.ok);
    });
  });

  group('Router Sub-routing & Groups', () {
    test('supports route(...) sub-routing', () async {
      final app = Router();
      app.route('/users', (r) {
        r.get('/', (req) => Response.text('users index'));
        r.get('/{id}', (req) => Response.text('user:${req.param('id')}'));
      });

      check((await req(app, .get, '/users')).status).equals(HttpStatusCode.ok);
      check(
        (await req(app, .get, '/users/42')).status,
      ).equals(HttpStatusCode.ok);
    });

    test('supports mount(...) standalone router mounting', () async {
      final admin = Router()
        ..get('/dashboard', (req) => Response.text('admin dashboard'))
        ..get('/settings', (req) => Response.text('admin settings'));

      final app = Router()..mount('/admin', admin.call);

      check(
        (await req(app, .get, '/admin/dashboard')).status,
      ).equals(HttpStatusCode.ok);
      check(
        (await req(app, .get, '/admin/settings')).status,
      ).equals(HttpStatusCode.ok);
    });

    test('supports mount(...) on root path /', () async {
      final subApp = Router()
        ..get('/', (req) => Response.text('root index'))
        ..get('/ping', (req) => Response.text('pong'));

      final app = Router()..mount('/', subApp.call);

      check((await req(app, .get, '/')).bodyText).equals('root index');
      check((await req(app, .get, '/ping')).bodyText).equals('pong');
    });

    test('supports middleware group(...) scoping', () async {
      final trace = <String>[];

      Middleware logMw(String name) {
        return (next) => (req) {
          trace.add(name);
          return next(req);
        };
      }

      final app = Router()
        ..use(logMw('global'))
        ..get('/public', (req) => Response.text('public'))
        ..group((r) {
          r.use(logMw('auth'));
          r.get('/private', (req) => Response.text('private'));
        });

      await req(app, .get, '/public');
      check(trace).deepEquals(['global']);

      trace.clear();
      await req(app, .get, '/private');
      check(trace).deepEquals(['global', 'auth']);
    });

    test('supports nested route(...) with scoped middlewares', () async {
      final trace = <String>[];

      Middleware logMw(String name) {
        return (next) => (req) {
          trace.add(name);
          return next(req);
        };
      }

      final app = Router()
        ..use(logMw('root'))
        ..route('/api/v1', (v1) {
          v1.use(logMw('v1'));
          v1.get('/ping', (req) => Response.text('pong'));
          v1.route('/users', (users) {
            users.use(logMw('usersMw'));
            users.get(
              '/{id}',
              (req) => Response.text('user:${req.param('id')}'),
            );
          });
        });

      await req(app, .get, '/api/v1/ping');
      check(trace).deepEquals(['root', 'v1']);

      trace.clear();
      await req(app, .get, '/api/v1/users/99');
      check(trace).deepEquals(['root', 'v1', 'usersMw']);
    });
  });

  group('Router Error Handling', () {
    test('returns 404 for unknown routes', () async {
      final app = Router()..get('/hello', (req) => Response.text('hello'));

      final res = await req(app, .get, '/unknown');
      check(res.status).equals(HttpStatusCode.notFound);
    });

    test('returns custom notFound handler', () async {
      final app = Router()
        ..get('/hello', (req) => Response.text('hello'))
        ..notFound((req) => Response.text('custom 404', status: .notFound));

      final res = await req(app, .get, '/missing');
      check(res.status).equals(HttpStatusCode.notFound);
    });

    test('returns 405 Method Not Allowed with Allow header', () async {
      final app = Router()
        ..get('/users', (req) => Response.text('get users'))
        ..post('/users', (req) => Response.text('post users'));

      final res = await req(app, .delete, '/users');
      check(res.status).equals(HttpStatusCode.methodNotAllowed);
      check(res.header('Allow')).isNotNull().contains('GET');
      check(res.header('Allow')).isNotNull().contains('POST');
    });

    test('returns custom methodNotAllowed handler', () async {
      final app = Router()
        ..get('/users', (req) => Response.text('get users'))
        ..methodNotAllowed(
          (req) => Response.text('custom 405', status: .methodNotAllowed),
        );

      final res = await req(app, .delete, '/users');
      check(res.status).equals(HttpStatusCode.methodNotAllowed);
    });

    test('throws StateError when use() is called after routes', () {
      final app = Router()..get('/hello', (req) => Response.text('hello'));

      check(
        () => app.use(
          (next) {
            return (req) => next(req);
          },
        ),
      ).throws<StateError>();
    });

    test('throws ArgumentError on invalid patterns or duplicate keys', () {
      final app = Router();

      check(
        () => app.get('/users/*/{id}', (req) => Response.text('err')),
      ).throws<ArgumentError>();
      check(
        () => app.get('/users/{id}/{id}', (req) => Response.text('err')),
      ).throws<ArgumentError>();
    });

    test(
      'executes inline group middlewares on mounted sub-router sub-paths',
      () async {
        final trace = <String>[];
        Middleware mw(String label) {
          return (next) => (req) {
            trace.add(label);
            return next(req);
          };
        }

        final subApp = Router()
          ..get('/dashboard', (req) => Response.text('admin dashboard'));

        final app = Router()
          ..group((r) {
            r.use(mw('groupMw'));
            r.mount('/admin', subApp.call);
          });

        final res = await req(app, .get, '/admin/dashboard');
        check(res.status).equals(HttpStatusCode.ok);
        check(trace).deepEquals(['groupMw']);
      },
    );

    test(
      'matches wildcard with trailing slash pattern and empty param',
      () async {
        final app = Router()
          ..get('/static/*', (req) => Response.text('file:${req.param('*')}'));

        final res = await req(app, .get, '/static/');
        check(res.status).equals(HttpStatusCode.ok);
        check(res.bodyText).equals('file:');
      },
    );

    test(
      'throws StateError when use() is called after routes in inline router',
      () {
        final app = Router();
        app.group((r) {
          r.get('/hello', (req) => Response.text('hello'));
          check(
            () => r.use((next) {
              return (req) => next(req);
            }),
          ).throws<StateError>();
        });
      },
    );

    group('Routes Interface', () {
      test('routes() returns registered routes with correct patterns', () {
        final r = Router();
        r.get('/users', (_) => const .status(.ok));
        r.post('/users', (_) => const .status(.ok));
        r.get('/users/{id}', (_) => const .status(.ok));
        r.delete('/users/{id}', (_) => const .status(.ok));

        final routes = r.routes();
        final patterns = routes.map((r) => r.pattern).toSet();
        check(patterns)
          ..contains('/users')
          ..contains('/users/{id}');
      });

      test('routes() includes correct HTTP methods per pattern', () {
        final r = Router();
        r.get('/items', (_) => const .status(.ok));
        r.post('/items', (_) => const .status(.ok));

        final routes = r.routes();
        final itemRoutes = routes.where((r) => r.pattern == '/items');
        final allMethods = itemRoutes
            .map((r) => r.method)
            .whereType<HttpMethod>()
            .toSet();
        check(allMethods)
          ..contains(HttpMethod.get)
          ..contains(HttpMethod.post);
      });

      test('middlewares() returns registered middlewares', () {
        final r = Router();
        Handler mw(Handler next) => next;
        r.use(mw);

        check(r.middlewares()).length.equals(1);
      });

      test('middlewares() returns empty list when none registered', () {
        final r = Router();
        r.get('/', (_) => const .status(.ok));
        check(r.middlewares()).isEmpty();
      });

      test('match() returns true for existing routes', () {
        final r = Router();
        r.get('/users', (_) => const .status(.ok));
        r.post('/users', (_) => const .status(.ok));

        check(r.match(HttpMethod.get, '/users')).isTrue();
        check(r.match(HttpMethod.post, '/users')).isTrue();
      });

      test('match() returns false for non-existing routes', () {
        final r = Router();
        r.get('/users', (_) => const .status(.ok));

        check(r.match(HttpMethod.get, '/nope')).isFalse();
      });

      test('match() works with parameterized routes', () {
        final r = Router();
        r.get('/users/{id}', (_) => const .status(.ok));

        check(r.match(HttpMethod.get, '/users/42')).isTrue();
        check(r.match(HttpMethod.get, '/users')).isFalse();
      });

      test('find() returns matched pattern', () {
        final r = Router();
        r.get('/users', (_) => const .status(.ok));
        r.get('/users/{id}', (_) => const .status(.ok));

        check(r.find(HttpMethod.get, '/users')).equals('/users');
        check(r.find(HttpMethod.get, '/users/42')).equals('/users/{id}');
      });

      test('find() returns null for non-existing routes', () {
        final r = Router();
        r.get('/users', (_) => const .status(.ok));

        check(r.find(HttpMethod.get, '/nope')).isNull();
      });
    });

    group('Meta Annotations', () {
      test('meta is stored and retrievable through routes()', () {
        final r = Router();
        r.get(
          '/users',
          (_) => const .status(.ok),
          meta: [const _TestMeta('list users'), const _Tag('users')],
        );

        final routes = r.routes();
        final route = routes.firstWhere((r) => r.pattern == '/users');
        check(route.meta).length.equals(2);

        final desc = route.metaOf<_TestMeta>();
        check(desc)
            .isNotNull()
            .has((d) => d.summary, 'summary')
            .equals(
              'list users',
            );

        final tag = route.metaOf<_Tag>();
        check(tag).isNotNull().has((t) => t.name, 'name').equals('users');
      });

      test('metaOf returns null when annotation type not found', () {
        final r = Router();
        r.get('/users', (_) => const .status(.ok), meta: [const _Tag('users')]);

        final routes = r.routes();
        final route = routes.firstWhere((r) => r.pattern == '/users');
        check(route.metaOf<_TestMeta>()).isNull();
      });

      test('metaAll returns all annotations of given type', () {
        final r = Router();
        r.get(
          '/users',
          (_) => const .status(.ok),
          meta: [const _Tag('users'), const _Tag('public')],
        );

        final routes = r.routes();
        final route = routes.firstWhere((r) => r.pattern == '/users');
        final tags = route.metaAll<_Tag>();
        check(tags).length.equals(2);
        check(tags.map((t) => t.name)).deepEquals(['users', 'public']);
      });

      test('routes without meta have empty meta list', () {
        final r = Router();
        r.get('/users', (_) => const .status(.ok));

        final routes = r.routes();
        final route = routes.firstWhere((r) => r.pattern == '/users');
        check(route.meta).isEmpty();
      });
    });

    group('walk()', () {
      test('walks all routes with method and pattern', () {
        final r = Router();
        r.get('/a', (_) => const .status(.ok));
        r.post('/b', (_) => const .status(.ok));

        final visited = <String>[];
        r.walk((method, fullRoute, mws, meta) {
          visited.add('${method.value} $fullRoute');
        });

        check(visited)
          ..contains('GET /a')
          ..contains('POST /b');
      });

      test('walk includes meta annotations', () {
        final r = Router();
        r.get(
          '/users',
          (_) => const .status(.ok),
          meta: [const _TestMeta('list')],
        );

        r.walk((method, fullRoute, mws, meta) {
          check(meta).length.equals(1);
          final m = meta.first;
          check(m)
              .isA<_TestMeta>()
              .has((m) => m.summary, 'summary')
              .equals(
                'list',
              );
        });
      });

      test(
        'walk preserves distinct meta for different HTTP methods '
        'on same pattern',
        () {
          final r = Router();
          r.post(
            '/todos',
            (_) => const .status(.ok),
            meta: [const _TestMeta('create')],
          );
          r.get(
            '/todos',
            (_) => const .status(.ok),
            meta: [const _TestMeta('list')],
          );

          final metaByMethod = <String, String>{};
          r.walk((method, fullRoute, mws, meta) {
            metaByMethod[method.value] = (meta.first as _TestMeta).summary;
          });

          check(metaByMethod['POST']).equals('create');
          check(metaByMethod['GET']).equals('list');
        },
      );

      test('walk sees routes from merged sub-routers', () {
        final adminRouter = Router()
          ..get('/admin/stats', (_) => const .status(.ok))
          ..get('/admin/logs', (_) => const .status(.ok));

        final app = Router()
          ..get('/health', (_) => const .status(.ok))
          ..merge(adminRouter);

        final visited = <String>[];
        app.walk((method, fullRoute, mws, meta) {
          visited.add('${method.value} $fullRoute');
        });

        check(visited)
          ..contains('GET /health')
          ..contains('GET /admin/stats')
          ..contains('GET /admin/logs');
      });

      test('merged routes are callable', () async {
        final adminRouter = Router()
          ..get('/admin/stats', (req) => Response.text('admin stats'));

        final app = Router()
          ..get('/health', (req) => Response.text('ok'))
          ..merge(adminRouter);

        check((await req(app, .get, '/health')).bodyText).equals('ok');
        check(
          (await req(app, .get, '/admin/stats')).bodyText,
        ).equals('admin stats');
      });

      test('merge preserves sub-router middlewares', () async {
        final trace = <String>[];

        final adminRouter = Router()
          ..use(
            (next) => (req) {
              trace.add('adminMw');
              return next(req);
            },
          )
          ..get('/admin/stats', (req) => Response.text('stats'));

        final app = Router()
          ..use(
            (next) => (req) {
              trace.add('rootMw');
              return next(req);
            },
          )
          ..merge(adminRouter);

        await req(app, .get, '/admin/stats');
        check(trace).deepEquals(['rootMw', 'adminMw']);
      });

      test('automatically falls back to GET route for HEAD requests', () async {
        final app = Router()..get('/items', (req) => .text('item list'));

        final headRes = await req(app, .head, '/items');
        check(headRes.status.value).equals(200);
        check(headRes.bodyText).equals('item list');
      });
    });
  });
}

class _TestMeta {
  const _TestMeta(this.summary);
  final String summary;
}

class _Tag {
  const _Tag(this.name);
  final String name;
}

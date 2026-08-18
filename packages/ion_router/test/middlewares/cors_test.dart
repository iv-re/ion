import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:ion_router/ion_router.dart';
import 'package:ion_web/ion_web.dart';
import 'package:test/scaffolding.dart';

Future<Response> _runCors(
  Middleware middleware, {
  HttpMethod method = HttpMethod.get,
  Map<String, String>? headers,
  List<MapEntry<String, String>>? multiHeaders,
}) async {
  final app = IonRouter()
    ..use(middleware)
    ..options('/test', (req) => Response.text('preflight options passthrough'))
    ..get('/test', (req) => Response.text('ok'))
    ..post('/test', (req) => Response.text('ok_post'));

  final slices = <HeaderEntrySlices>[];
  final token = SliceBufferToken();

  if (multiHeaders != null) {
    for (final entry in multiHeaders) {
      final keyBytes = Uint8List.fromList(entry.key.codeUnits);
      final valBytes = Uint8List.fromList(entry.value.codeUnits);
      slices.add(
        HeaderEntrySlices(
          HeaderByteSlice(keyBytes, 0, keyBytes.length, token),
          HeaderByteSlice(valBytes, 0, valBytes.length, token),
        ),
      );
    }
  } else if (headers != null) {
    for (final entry in headers.entries) {
      final keyBytes = Uint8List.fromList(entry.key.codeUnits);
      final valBytes = Uint8List.fromList(entry.value.codeUnits);
      slices.add(
        HeaderEntrySlices(
          HeaderByteSlice(keyBytes, 0, keyBytes.length, token),
          HeaderByteSlice(valBytes, 0, valBytes.length, token),
        ),
      );
    }
  }

  final request = Request(
    const Stream.empty(),
    method: method,
    uri: Uri.parse('http://localhost/test'),
    version: HttpVersion.http11,
    headers: TypedHeaders(slices),
  );

  return app(request);
}

void main() {
  group('CORS Middleware - Non-CORS requests', () {
    test('passes through unchanged when no Origin header is present', () async {
      final res = await _runCors(Middlewares.cors());
      check(res.status).equals(HttpStatusCode.ok);
      check(res.headers.get<AccessControlAllowOriginHeader>()).isNull();
    });

    test('passes through when Origin header is empty', () async {
      final res = await _runCors(
        Middlewares.cors(),
        headers: {'Origin': '   '},
      );
      check(res.status).equals(HttpStatusCode.ok);
      check(res.headers.get<AccessControlAllowOriginHeader>()).isNull();
    });
  });

  group('CORS Middleware - Default & AllowAll options', () {
    test(
      'returns wildcard Access-Control-Allow-Origin for matching origin',
      () async {
        final res = await _runCors(
          Middlewares.cors(),
          headers: {'Origin': 'https://app.example.com'},
        );
        check(res.status).equals(HttpStatusCode.ok);
        check(
          res.headers.get<AccessControlAllowOriginHeader>(),
        ).isA<AccessControlAllowOriginAny>();
      },
    );

    test('handles default preflight OPTIONS request', () async {
      final res = await _runCors(
        Middlewares.cors(),
        method: HttpMethod.options,
        headers: {
          'Origin': 'https://app.example.com',
          'Access-Control-Request-Method': 'POST',
        },
      );
      check(res.status).equals(HttpStatusCode.noContent);
      check(
        res.headers.get<AccessControlAllowOriginHeader>(),
      ).isA<AccessControlAllowOriginAny>();
      check(
        res.headers.get<AccessControlAllowMethodsHeader>()?.methods,
      ).isNotNull().contains('POST');
      check(
          res.headers.get<VaryHeader>()?.headers,
        ).isNotNull()
        ..contains('Origin')
        ..contains('Access-Control-Request-Method')
        ..contains('Access-Control-Request-Headers');
    });

    test('supports CorsOptions.allowAll() permissive constructor', () async {
      final mw = Middlewares.cors(CorsOptions.allowAll());
      final res = await _runCors(
        mw,
        method: HttpMethod.options,
        headers: {
          'Origin': 'https://foo.bar.com',
          'Access-Control-Request-Method': 'DELETE',
          'Access-Control-Request-Headers': 'X-Custom-Header',
        },
      );
      check(res.status).equals(HttpStatusCode.noContent);
      check(
        res.headers.get<AccessControlAllowOriginHeader>(),
      ).isA<AccessControlAllowOriginAny>();
      check(
        res.headers.get<AccessControlAllowHeadersHeader>()?.headers,
      ).isNotNull().contains('X-Custom-Header');
    });
  });

  group('CORS Middleware - Origin Validation', () {
    test('allows exact matching origin', () async {
      final res = await _runCors(
        Middlewares.cors(
          CorsOptions(allowedOrigins: ['https://example.com']),
        ),
        headers: {'Origin': 'https://example.com'},
      );
      final header = res.headers.get<AccessControlAllowOriginHeader>();
      check(header)
          .isA<AccessControlAllowOriginValue>()
          .has(
            (h) => h.origin,
            'origin',
          )
          .equals('https://example.com');
      check(
        res.headers.get<VaryHeader>()?.headers,
      ).isNotNull().contains('Origin');
    });

    test('allows wildcard domain pattern matching', () async {
      final mw = Middlewares.cors(
        CorsOptions(allowedOrigins: ['https://*.domain.com']),
      );

      final res1 = await _runCors(
        mw,
        headers: {'Origin': 'https://sub.domain.com'},
      );
      final header1 = res1.headers.get<AccessControlAllowOriginHeader>();
      check(header1)
          .isA<AccessControlAllowOriginValue>()
          .has(
            (h) => h.origin,
            'origin',
          )
          .equals('https://sub.domain.com');

      final res2 = await _runCors(
        mw,
        headers: {'Origin': 'https://other.com'},
      );
      check(res2.headers.get<AccessControlAllowOriginHeader>()).isNull();
    });

    test('supports custom allowOriginFunc', () async {
      final mw = Middlewares.cors(
        CorsOptions(
          allowOriginFunc: (req, origin) => origin.endsWith('.custom.io'),
        ),
      );

      final res1 = await _runCors(
        mw,
        headers: {'Origin': 'https://test.custom.io'},
      );
      final header1 = res1.headers.get<AccessControlAllowOriginHeader>();
      check(header1)
          .isA<AccessControlAllowOriginValue>()
          .has(
            (h) => h.origin,
            'origin',
          )
          .equals('https://test.custom.io');

      final res2 = await _runCors(
        mw,
        headers: {'Origin': 'https://test.bad.io'},
      );
      check(res2.headers.get<AccessControlAllowOriginHeader>()).isNull();
    });
  });

  group('CORS Middleware - Methods and Headers Filtering', () {
    test('rejects preflight when requested method is not allowed', () async {
      final res = await _runCors(
        Middlewares.cors(
          CorsOptions(
            allowedOrigins: ['https://foobar.com'],
            allowedMethods: [HttpMethod.put, HttpMethod.delete],
          ),
        ),
        method: HttpMethod.options,
        headers: {
          'Origin': 'https://foobar.com',
          'Access-Control-Request-Method': 'PATCH',
        },
      );
      check(res.status).equals(HttpStatusCode.noContent);
      check(res.headers.get<AccessControlAllowOriginHeader>()).isNull();
    });

    test('rejects preflight when requested headers are not allowed', () async {
      final res = await _runCors(
        Middlewares.cors(
          CorsOptions(
            allowedOrigins: ['https://foobar.com'],
            allowedHeaders: const [
              HttpHeader('X-Header-1'),
              HttpHeader('X-Header-2'),
            ],
          ),
        ),
        method: HttpMethod.options,
        headers: {
          'Origin': 'https://foobar.com',
          'Access-Control-Request-Method': 'GET',
          'Access-Control-Request-Headers': 'X-Header-3, X-Header-1',
        },
      );
      check(res.status).equals(HttpStatusCode.noContent);
      check(res.headers.get<AccessControlAllowOriginHeader>()).isNull();
    });

    test(
      'always allows Origin header in Access-Control-Request-Headers',
      () async {
        final res = await _runCors(
          Middlewares.cors(
            CorsOptions(
              allowedOrigins: ['https://foobar.com'],
              allowedHeaders: const [],
            ),
          ),
          method: HttpMethod.options,
          headers: {
            'Origin': 'https://foobar.com',
            'Access-Control-Request-Method': 'GET',
            'Access-Control-Request-Headers': 'origin',
          },
        );
        check(res.status).equals(HttpStatusCode.noContent);
        check(
          res.headers.get<AccessControlAllowOriginHeader>(),
        ).isNotNull();
      },
    );

    test('handles non-preflight OPTIONS request with Origin', () async {
      final res = await _runCors(
        Middlewares.cors(
          CorsOptions(allowedOrigins: ['https://foobar.com']),
        ),
        method: HttpMethod.options,
        headers: {
          'Origin': 'https://foobar.com',
        },
      );
      check(res.status).equals(HttpStatusCode.ok);
      final header = res.headers.get<AccessControlAllowOriginHeader>();
      check(header)
          .isA<AccessControlAllowOriginValue>()
          .has(
            (h) => h.origin,
            'origin',
          )
          .equals('https://foobar.com');
    });
  });

  group('CORS Middleware - Credentials & Preflight Options', () {
    test(
      'sets Access-Control-Allow-Credentials when allowCredentials is true',
      () async {
        final res = await _runCors(
          Middlewares.cors(
            CorsOptions(
              allowedOrigins: ['https://example.com'],
              allowCredentials: true,
            ),
          ),
          headers: {'Origin': 'https://example.com'},
        );
        check(
          res.headers.get<AccessControlAllowCredentialsHeader>(),
        ).equals(const AccessControlAllowCredentialsHeader());
      },
    );

    test('sets Access-Control-Max-Age on preflight response', () async {
      final res = await _runCors(
        Middlewares.cors(
          CorsOptions(
            allowedOrigins: ['https://example.com'],
            maxAge: const Duration(hours: 1),
          ),
        ),
        method: HttpMethod.options,
        headers: {
          'Origin': 'https://example.com',
          'Access-Control-Request-Method': 'POST',
        },
      );
      check(
        res.headers.get<AccessControlMaxAgeHeader>()?.duration,
      ).equals(const Duration(hours: 1));
    });

    test(
      'exposes specified headers via Access-Control-Expose-Headers',
      () async {
        final res = await _runCors(
          Middlewares.cors(
            CorsOptions(
              allowedOrigins: ['https://example.com'],
              exposedHeaders: const [
                HttpHeader('X-Custom-Header'),
                HttpHeader('X-Total-Count'),
              ],
            ),
          ),
          headers: {'Origin': 'https://example.com'},
        );
        check(
          res.headers.get<AccessControlExposeHeadersHeader>()?.headers,
        ).isNotNull().contains('X-Custom-Header');
      },
    );

    test('supports optionsPassthrough to next handler', () async {
      final res = await _runCors(
        Middlewares.cors(
          CorsOptions(
            allowedOrigins: ['https://example.com'],
            optionsPassthrough: true,
          ),
        ),
        method: HttpMethod.options,
        headers: {
          'Origin': 'https://example.com',
          'Access-Control-Request-Method': 'GET',
        },
      );
      check(res.status).equals(HttpStatusCode.ok);
      final header = res.headers.get<AccessControlAllowOriginHeader>();
      check(header)
          .isA<AccessControlAllowOriginValue>()
          .has(
            (h) => h.origin,
            'origin',
          )
          .equals('https://example.com');
    });
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:ion_extra/ion_extra.dart';
import 'package:ion_router/ion_router.dart';
import 'package:ion_test/ion_test.dart';
import 'package:ion_web/ion_web.dart';
import 'package:test/scaffolding.dart';
import 'package:test/test.dart' show TestFailure, isA;

class _TestUserDto implements ToJson {
  _TestUserDto({required this.id, required this.name});

  final int id;
  final String name;

  @override
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

final class _TestHeader implements TypedHeader {
  const _TestHeader(this.name, this.value);
  @override
  final String name;
  final String value;
  @override
  Iterable<String> encode() => [value];
}

class _HtmlResponse extends Response {
  _HtmlResponse(String html)
    : super.bytes(
        utf8.encode(html),
        status: .ok,
        headers: [const .contentType('text/html; charset=utf-8')],
      );
}

void main() {
  group('ionTest', () {
    late Router app;

    setUp(() {
      app = Router()
        ..get('/text', (req) => Response.text('Hello World'))
        ..get('/raw-json', (req) => RawJson({'success': true}))
        ..get('/user', (req) => Json(_TestUserDto(id: 1, name: 'Alice')))
        ..get(
          '/users',
          (req) => JsonList([
            _TestUserDto(id: 1, name: 'Alice'),
            _TestUserDto(id: 2, name: 'Bob'),
          ]),
        )
        ..get('/html', (req) => _HtmlResponse('<h1>Hello Ion</h1>'))
        ..post('/echo', (req) async {
          final data = await req.rawJson();
          return RawJson({'echoed': data});
        })
        ..put('/items/1', (req) async {
          final data = await req.rawJson();
          return RawJson({'updated': data});
        })
        ..patch('/items/1', (req) async {
          final data = await req.rawJson();
          return RawJson({'patched': data});
        })
        ..delete('/item', (req) => const Response.status(.noContent))
        ..get('/stream', (req) {
          final controller = StreamController<Uint8List>();
          controller.add(Uint8List.fromList(utf8.encode('streamed data')));
          controller.close();
          return Response(
            status: .ok,
            headers: const [
              .contentType('text/plain', charset: 'utf-8'),
            ],
            body: ResponseBody.stream(controller.stream),
          );
        })
        ..get('/custom-headers', (req) {
          final customHeader = req.headers.entries.firstWhere(
            (e) => e.key == 'x-test',
            orElse: () => const MapEntry('', ''),
          );
          return RawJson({'header': customHeader.value});
        })
        ..get('/search', (req) {
          final page = req.uri.queryParameters['page'];
          final q = req.uri.queryParameters['q'];
          return RawJson({'page': page, 'q': q});
        })
        ..post('/form', (req) async {
          final bodyBytes = await req.fold<List<int>>(
            [],
            (a, b) => a..addAll(b),
          );
          final bodyStr = utf8.decode(bodyBytes);
          return Response.text('received:$bodyStr');
        })
        ..post('/upload', (req) async {
          final form = await req.multipart();
          final username = form.field('username');
          final file = form.files['file']?.first;
          final fileText = file != null ? await file.text() : '';
          return RawJson({
            'field': 'username:$username',
            'file': '${file?.filename}:$fileText',
          });
        })
        ..head('/headers-only', (req) {
          return Response.bytes(
            Uint8List(0),
            headers: [const .contentType('application/json')],
          );
        })
        ..options('/cors', (req) {
          return Response.bytes(
            Uint8List(0),
            status: .noContent,
            headers: [.accessControlAllowOrigin(const .any())],
          );
        })
        ..get('/sse', (req) {
          return Response.sse(() async* {
            yield const SseEvent.text('Hello World', event: 'greeting');
            yield const SseEvent.json({'status': 'ok'}, id: '1');
          });
        })
        ..get('/error', (req) => throw StateError('something went wrong'));
    });

    ionTest(
      'handles Response.text correctly',
      build: () => app.call,
      act: (c) => c.get('/text'),
      expect: () => Response.text('Hello World'),
    );

    ionTest(
      'handles RawJson map correctly',
      build: () => app.call,
      act: (c) => c.get('/raw-json'),
      expect: () => RawJson({'success': true}),
    );

    ionTest(
      'handles Json single DTO object correctly',
      build: () => app.call,
      act: (c) => c.get('/user'),
      expect: () => Json(_TestUserDto(id: 1, name: 'Alice')),
    );

    ionTest(
      'handles JsonList DTO array correctly',
      build: () => app.call,
      act: (c) => c.get('/users'),
      expect: () => JsonList([
        _TestUserDto(id: 1, name: 'Alice'),
        _TestUserDto(id: 2, name: 'Bob'),
      ]),
    );

    ionTest(
      'handles custom HTML response subclass',
      build: () => app.call,
      act: (c) => c.get('/html'),
      expect: () => _HtmlResponse('<h1>Hello Ion</h1>'),
    );

    ionTest(
      'handles POST request with TestBody.rawJson',
      build: () => app.call,
      act: (c) => c.post('/echo', body: .rawJson({'msg': 'hi'})),
      expect: () => RawJson({
        'echoed': {'msg': 'hi'},
      }),
    );

    ionTest(
      'handles PUT request with TestBody.json (ToJson object)',
      build: () => app.call,
      act: (c) => c.put(
        '/items/1',
        body: .json(_TestUserDto(id: 1, name: 'Alice')),
      ),
      expect: () => RawJson({
        'updated': {'id': 1, 'name': 'Alice'},
      }),
    );

    ionTest(
      'handles PATCH request with TestBody.jsonList (Iterable<ToJson>)',
      build: () => app.call,
      act: (c) => c.patch(
        '/items/1',
        body: .jsonList([_TestUserDto(id: 1, name: 'Alice')]),
      ),
      expect: () => RawJson({
        'patched': [
          {'id': 1, 'name': 'Alice'},
        ],
      }),
    );

    ionTest(
      'handles 204 No Content response',
      build: () => app.call,
      act: (c) => c.delete('/item'),
      expect: () => const Response.status(.noContent),
    );

    ionTest(
      'handles StreamResponseBody correctly',
      build: () => app.call,
      act: (c) => c.get('/stream'),
      expect: () => Response.text('streamed data'),
    );

    ionTest(
      'sends custom headers and bytes TestBody correctly',
      build: () => app.call,
      act: (c) => c.get(
        '/custom-headers',
        headers: [const _TestHeader('x-test', 'my-header-val')],
      ),
      expect: () => RawJson({'header': 'my-header-val'}),
    );

    ionTest(
      'handles query parameters correctly',
      build: () => app.call,
      act: (c) => c.get('/search', query: {'page': '1', 'q': 'dart'}),
      expect: () => RawJson({'page': '1', 'q': 'dart'}),
    );

    ionTest(
      'handles TestBody.formUrlEncoded correctly',
      build: () => app.call,
      act: (c) => c.post(
        '/form',
        body: .formUrlEncoded({'user': 'alice', 'role': 'admin'}),
      ),
      expect: () => Response.text('received:user=alice&role=admin'),
    );

    ionTest(
      'handles TestBody.formData with FormDataPart correctly',
      build: () => app.call,
      act: (c) => c.post(
        '/upload',
        body: .formData({
          'username': const .field('alice'),
          'file': .file(
            Uint8List.fromList(utf8.encode('hello world')),
            filename: 'hello.txt',
            contentType: 'text/plain',
          ),
        }),
      ),
      expect: () => RawJson({
        'field': 'username:alice',
        'file': 'hello.txt:hello world',
      }),
    );

    ionTest(
      'handles HEAD request correctly',
      build: () => app.call,
      act: (c) => c.head('/headers-only'),
      expect: () => Response.bytes(
        Uint8List(0),
        headers: [const .contentType('application/json')],
      ),
    );

    ionTest(
      'handles OPTIONS request correctly',
      build: () => app.call,
      act: (c) => c.options('/cors'),
      expect: () => Response.bytes(
        Uint8List(0),
        status: .noContent,
        headers: [.accessControlAllowOrigin(const .any())],
      ),
    );

    ionTest(
      'sends raw Request directly via client.send(request)',
      build: () => app.call,
      act: (c) => c.send(
        Request(
          const Stream.empty(),
          method: .get,
          uri: Uri.parse('http://localhost/text'),
          version: .http11,
          headers: TypedHeaders.fromList([]),
        ),
      ),
      expect: () => Response.text('Hello World'),
    );

    ionTest(
      'handles Response.sse correctly with c.get',
      build: () => app.call,
      act: (c) => c.get('/sse'),
      expect: () => Response.sse(() async* {
        yield const SseEvent.text('Hello World', event: 'greeting');
        yield const SseEvent.json({'status': 'ok'}, id: '1');
      }),
    );

    // Lifecycle callbacks: setUp, wait, verify, tearDown
    var setUpCalled = false;
    var tearDownCalled = false;
    var verifyCalled = false;

    ionTest(
      'executes setUp, wait, verify, and tearDown callbacks',
      setUp: () {
        setUpCalled = true;
      },
      build: () => app.call,
      act: (c) => c.get('/text'),
      wait: const Duration(milliseconds: 10),
      expect: () => Response.text('Hello World'),
      verify: (target, response) {
        verifyCalled = true;
        check(response.status).equals(HttpStatusCode.ok);
      },
      tearDown: () {
        tearDownCalled = true;
      },
    );

    test('verifies lifecycle flags were executed', () {
      check(setUpCalled).isTrue();
      check(verifyCalled).isTrue();
      check(tearDownCalled).isTrue();
    });

    // Custom Matcher expect
    ionTest(
      'supports custom Matcher in expect callback',
      build: () => app.call,
      act: (c) => c.get('/text'),
      expect: () => isA<Response>(),
    );

    // Expected thrown errors
    ionTest(
      'catches and verifies expected errors via errors callback',
      build: () => app.call,
      act: (c) => c.get('/error'),
      errors: () => isA<StateError>(),
    );
  });

  group('IonTestClient', () {
    test('executes requests directly', () async {
      final app = Router()..get('/test', (req) => Response.text('OK'));
      final client = IonTestClient(app.call);
      final response = await client.get('/test');

      check(response.status).equals(HttpStatusCode.ok);
    });

    test('auto-resolves ResolvableResponse (e.g. Response.content)', () async {
      final sample = utf8.encode('Hello, Resolvable World!');
      final app = Router()
        ..get('/file', (req) {
          return Response.content(
            read: (start, end) => Stream.value(
              Uint8List.fromList(sample.sublist(start, end)),
            ),
            size: sample.length,
            name: 'hello.txt',
            lastModified: DateTime.utc(2025),
            headers: [ETagHeader.strong('v1')],
          );
        });

      final client = IonTestClient(app.call);

      // Full content request
      final response = await client.get('/file');
      check(response.status).equals(HttpStatusCode.ok);
      check(
        response.headers.get<ContentTypeHeader>()?.value,
      ).equals('text/plain');
      final bytes = await response.readBytes();
      check(bytes).deepEquals(sample);

      // Range request (206 Partial Content)
      final rangeResponse = await client.get(
        '/file',
        headers: [const .range('bytes=0-4')],
      );
      check(rangeResponse.status).equals(HttpStatusCode.partialContent);
      check(await rangeResponse.readText()).equals('Hello');

      // Conditional request (304 Not Modified)
      final notModifiedResponse = await client.get(
        '/file',
        headers: [IfNoneMatchHeader.etag(const EntityTag('v1'))],
      );
      check(notModifiedResponse.status).equals(HttpStatusCode.notModified);
    });
  });

  group('IonResponseUtils', () {
    test(
      'readText decodes response body with default UTF-8 and custom encoding',
      () async {
        final textRes = Response.text('Привет, мир!');
        check(await textRes.readText()).equals('Привет, мир!');

        const emptyRes = Response.status(.noContent);
        check(await emptyRes.readText()).equals('');

        final latin1Bytes = Uint8List.fromList([
          0x68,
          0x65,
          0x6c,
          0x6c,
          0x6f,
        ]);
        final latin1Res = Response.bytes(latin1Bytes);
        check(await latin1Res.readText(encoding: latin1)).equals('hello');
      },
    );

    test(
      'readBytes and readText are idempotent for StreamResponseBody',
      () async {
        final controller = StreamController<Uint8List>();
        controller.add(Uint8List.fromList(utf8.encode('chunk1 ')));
        controller.add(Uint8List.fromList(utf8.encode('chunk2')));
        unawaited(controller.close());

        final response = Response.stream(controller.stream);

        // Multiple reads do not throw "Stream has already been listened to"
        final bytes1 = await response.readBytes();
        final bytes2 = await response.readBytes();
        final text1 = await response.readText();
        final text2 = await response.readText();

        check(utf8.decode(bytes1)).equals('chunk1 chunk2');
        check(bytes2).deepEquals(bytes1);
        check(text1).equals('chunk1 chunk2');
        check(text2).equals('chunk1 chunk2');
      },
    );

    ionTest(
      'allows reading streamed response in both expect and verify',
      build: () {
        return (Router()..get('/stream-test', (req) {
              final controller = StreamController<Uint8List>();
              controller.add(
                Uint8List.fromList(utf8.encode('stream-data')),
              );
              controller.close();
              return Response.stream(
                controller.stream,
                headers: const [
                  .contentType('text/plain', charset: 'utf-8'),
                ],
              );
            }))
            .call;
      },
      act: (c) => c.get('/stream-test'),
      expect: () => Response.text('stream-data'),
      verify: (_, res) async {
        final bytes = await res.readBytes();
        check(bytes).isNotEmpty();
        check(await res.readText()).equals('stream-data');
      },
    );
  });

  group('ResponseComparator', () {
    late Router xmlApp;

    setUp(() {
      resetResponseComparators();
      xmlApp = Router()
        ..get(
          '/xml',
          (req) => Response.bytes(
            utf8.encode('<user id="1"/>'),
            headers: [const .contentType('application/xml')],
          ),
        );
    });

    tearDown(resetResponseComparators);

    test(
      'supports registering global custom ResponseComparator.byType',
      () async {
        var customComparatorCalled = false;

        registerResponseComparator(
          ResponseComparator.byType<_HtmlResponse>(
            compare: (actual, expected) async {
              customComparatorCalled = true;
              final actualBytes = await actual.readBytes();
              final expectedBytes = await expected.readBytes();
              check(actualBytes).deepEquals(expectedBytes);
            },
          ),
        );

        final app = Router()
          ..get('/html', (req) => _HtmlResponse('<h1>Hello</h1>'));
        final client = IonTestClient(app.call);
        final response = await client.get('/html');

        final active = getResponseComparators();
        check(
          active.first.canCompare(response, _HtmlResponse('<h1>Hello</h1>')),
        ).isTrue();
        await active.first.compare(response, _HtmlResponse('<h1>Hello</h1>'));
        check(customComparatorCalled).isTrue();
      },
    );

    ionTest(
      'uses locally passed ResponseComparator in ionTest',
      build: () => xmlApp.call,
      act: (c) => c.get('/xml'),
      expect: () => Response.bytes(
        utf8.encode('<user id="1"/>'),
        headers: [const .contentType('application/xml')],
      ),
      comparators: [
        ResponseComparator.byContentType(
          'xml',
          compare: (actual, expected) async {
            final actualStr = utf8.decode(await actual.readBytes());
            final expectedStr = utf8.decode(await expected.readBytes());
            check(actualStr.trim()).equals(expectedStr.trim());
          },
        ),
      ],
    );

    ionTest(
      'uses global registered ResponseComparator.custom',
      setUp: () {
        registerResponseComparator(
          ResponseComparator.custom(
            canCompare: (actual, expected) {
              final actualCt = actual.contentType ?? '';
              final expectedCt = expected.contentType ?? '';
              return actualCt.contains('xml') || expectedCt.contains('xml');
            },
            compare: (actual, expected) async {
              final actualStr = utf8.decode(await actual.readBytes());
              final expectedStr = utf8.decode(await expected.readBytes());
              check(actualStr).equals(expectedStr);
            },
          ),
        );
      },
      build: () => xmlApp.call,
      act: (c) => c.get('/xml'),
      expect: () => Response.bytes(
        utf8.encode('<user id="1"/>'),
        headers: [const .contentType('application/xml')],
      ),
    );

    test('supports unregistering global ResponseComparator', () {
      final comp = ResponseComparator.byContentType(
        'test-unregister',
        compare: (actual, expected) {},
      );

      registerResponseComparator(comp);
      check(getResponseComparators().contains(comp)).isTrue();

      unregisterResponseComparator(comp);
      check(getResponseComparators().contains(comp)).isFalse();
    });

    test(
      'JsonResponseComparator throws TestFailure with pretty diff on mismatch',
      () async {
        const comparator = JsonResponseComparator();
        final actual = RawJson({'id': 1, 'name': 'Alice'});
        final expected = RawJson({'id': 1, 'name': 'Bob'});

        await check(
          comparator.compare(actual, expected),
        ).throws<TestFailure>(
          (it) => it
              .has((e) => e.message, 'message')
              .isA<String>()
              .contains('diff'),
        );
      },
    );

    test(
      'SseResponseComparator throws TestFailure with diff on mismatch',
      () async {
        const comparator = SseResponseComparator();
        final actual = Response.sse(() async* {
          yield const SseEvent.text('Hello World', event: 'greeting');
        });
        final expected = Response.sse(() async* {
          yield const SseEvent.text('Goodbye World', event: 'greeting');
        });

        await check(
          comparator.compare(actual, expected),
        ).throws<TestFailure>(
          (it) => it
              .has((e) => e.message, 'message')
              .isA<String>()
              .contains('diff'),
        );
      },
    );

    test(
      'DefaultResponseComparator throws TestFailure with diff on mismatch',
      () async {
        const comparator = DefaultResponseComparator();
        final actual = Response.text('Hello Actual');
        final expected = Response.text('Hello Expected');

        await check(
          comparator.compare(actual, expected),
        ).throws<TestFailure>(
          (it) => it
              .has((e) => e.message, 'message')
              .isA<String>()
              .contains('diff'),
        );
      },
    );
  });
}

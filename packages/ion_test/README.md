# ion_test

In-process testing utilities for `ion_web` handlers.

## Usage

```dart
import 'package:ion_extra/ion_extra.dart';
import 'package:ion_router/ion_router.dart';
import 'package:ion_test/ion_test.dart';
import 'package:ion_web/ion_web.dart';

void main() {
  final app = Router()
    ..get('/ping', (req) => RawJson({'pong': true}))
    ..post('/echo', (req) async => Response.text('echo: ${await req.text()}'))
    ..get('/sse', (req) => Response.sse(() async* {
      yield const SseEvent.text('Hello', event: 'greeting');
      yield const SseEvent.json({'status': 'ok'});
    }));

  ionTest(
    'GET /ping returns JSON pong',
    build: () => app,
    act: (c) => c.get('/ping'),
    expect: () => RawJson({'pong': true}),
  );

  ionTest(
    'POST /echo returns echoed text',
    build: () => app,
    act: (c) => c.post('/echo', body: .text('hello')),
    expect: () => Response.text('echo: hello'),
  );

  ionTest(
    'GET /sse streams SSE events',
    build: () => app,
    act: (c) => c.get('/sse'),
    expect: () => Response.sse(() async* {
      yield const SseEvent.text('Hello', event: 'greeting');
      yield const SseEvent.json({'status': 'ok'});
    }),
  );
}
```

## Custom Response Comparators

Register custom comparators globally or per test:

```dart
// Register a comparator by Response subclass (e.g. XmlResponse):
registerResponseComparator(
  ResponseComparator.byType<XmlResponse>(
    compare: (actual, expected) async {
      final actualXml = XmlDocument.parse(utf8.decode(await actual.readBytes()));
      final expectedXml = XmlDocument.parse(utf8.decode(await expected.readBytes()));

      final actualFormatted = actualXml.toXmlString(pretty: true);
      final expectedFormatted = expectedXml.toXmlString(pretty: true);

      try {
        expect(actualFormatted, equals(expectedFormatted));
      } on TestFailure catch (e) {
        final diffText = formatDiff(expected: expectedFormatted, actual: actualFormatted);
        throw TestFailure('${e.message}\n$diffText');
      }
    },
  ),
);

// Register a comparator by Content-Type (e.g. Protobuf payload decoding):
registerResponseComparator(
  ResponseComparator.byContentType(
    'application/x-protobuf',
    compare: (actual, expected) async {
      final actualProto = UserProto.fromBuffer(await actual.readBytes());
      final expectedProto = UserProto.fromBuffer(await expected.readBytes());
      expect(actualProto, equals(expectedProto));
    },
  ),
);

// Or pass locally to ionTest:
ionTest(
  'GET /user/1 returns XML user',
  build: () => app.call,
  act: (c) => c.get('/user/1'),
  expect: () => XmlResponse(UserXmlDto(id: 1, name: 'Alice')),
  comparators: [xmlResponseComparator],
);
```

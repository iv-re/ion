import 'dart:async';
import 'dart:typed_data';

import 'package:ion_router/ion_router.dart';
import 'package:ion_web/ion_web.dart';
import 'package:test/test.dart';

extension on Response {
  String get bodyText {
    if (body case BytesResponseBody(:final bytes)) {
      return String.fromCharCodes(bytes);
    }
    return '';
  }
}

Request _makeRequest({
  Stream<Uint8List> body = const Stream.empty(),
  Iterable<TypedHeader> headers = const [],
}) {
  return Request(
    body,
    method: .post,
    uri: .parse('http://localhost/upload'),
    version: .http11,
    headers: .fromList(headers),
  );
}

Stream<Uint8List> _bodyOfSize(int bytes) {
  return Stream.value(Uint8List(bytes));
}

Stream<Uint8List> _chunkedBody(List<int> chunkSizes) {
  return Stream.fromIterable(chunkSizes.map(Uint8List.new));
}

void main() {
  group('bodyLimit middleware', () {
    late IonRouter app;

    setUp(() {
      app = IonRouter()
        ..use(Middlewares.bodyLimit(100))
        ..post('/upload', (req) async {
          // consume the body so the stream limit is exercised
          await req.toList();
          return .text('ok');
        });
    });

    group('Content-Length fast-path', () {
      test('allows request when Content-Length equals limit', () async {
        final res = await app(
          _makeRequest(
            body: _bodyOfSize(100),
            headers: [const .contentLength(100)],
          ),
        );
        expect(res.status, equals(HttpStatusCode.ok));
      });

      test('allows request when Content-Length is below limit', () async {
        final res = await app(
          _makeRequest(
            body: _bodyOfSize(50),
            headers: [const .contentLength(50)],
          ),
        );
        expect(res.status, equals(HttpStatusCode.ok));
      });

      test('rejects request when Content-Length exceeds limit', () async {
        final res = await app(
          _makeRequest(
            body: _bodyOfSize(200),
            headers: [const .contentLength(200)],
          ),
        );
        expect(res.status, equals(HttpStatusCode.contentTooLarge));
      });

      test('does not read body on fast-path rejection', () async {
        var bodyRead = false;
        final body = () async* {
          bodyRead = true;
          yield Uint8List(200);
        }();

        await app(
          _makeRequest(
            body: body,
            headers: [const .contentLength(200)],
          ),
        );

        expect(bodyRead, isFalse);
      });
    });

    group('stream counting (chunked / no Content-Length)', () {
      test('allows body exactly at limit', () async {
        final res = await app(_makeRequest(body: _bodyOfSize(100)));
        expect(res.status, equals(HttpStatusCode.ok));
      });

      test('allows body below limit', () async {
        final res = await app(_makeRequest(body: _bodyOfSize(42)));
        expect(res.status, equals(HttpStatusCode.ok));
      });

      test('rejects body exceeding limit in a single chunk', () async {
        final res = await app(_makeRequest(body: _bodyOfSize(101)));
        expect(res.status, equals(HttpStatusCode.contentTooLarge));
      });

      test('rejects body exceeding limit across multiple chunks', () async {
        // 3 chunks × 40 bytes = 120 bytes total > 100
        final res = await app(
          _makeRequest(body: _chunkedBody([40, 40, 40])),
        );
        expect(res.status, equals(HttpStatusCode.contentTooLarge));
      });

      test('allows body within limit split across multiple chunks', () async {
        // 3 chunks × 30 bytes = 90 bytes < 100
        final res = await app(
          _makeRequest(body: _chunkedBody([30, 30, 30])),
        );
        expect(res.status, equals(HttpStatusCode.ok));
      });
    });

    group('custom onExceeded callback', () {
      test('uses custom response when Content-Length exceeds limit', () async {
        final customApp = IonRouter()
          ..use(
            Middlewares.bodyLimit(
              100,
              onExceeded: (req) => .text('too big', status: .contentTooLarge),
            ),
          )
          ..post('/upload', (req) => .text('ok'));

        final res = await customApp(
          _makeRequest(
            body: _bodyOfSize(200),
            headers: [const .contentLength(200)],
          ),
        );
        expect(res.status, equals(HttpStatusCode.contentTooLarge));
        expect(res.bodyText, equals('too big'));
      });

      test('uses custom response when stream exceeds limit', () async {
        final customApp = IonRouter()
          ..use(
            Middlewares.bodyLimit(
              100,
              onExceeded: (req) => .text('too big', status: .contentTooLarge),
            ),
          )
          ..post('/upload', (req) async {
            await req.toList();
            return .text('ok');
          });

        final res = await customApp(_makeRequest(body: _bodyOfSize(200)));
        expect(res.status, equals(HttpStatusCode.contentTooLarge));
        expect(res.bodyText, equals('too big'));
      });
    });
  });
}

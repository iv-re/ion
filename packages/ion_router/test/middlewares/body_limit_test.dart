import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:ion_router/ion_router.dart';
import 'package:ion_web/ion_web.dart';
import 'package:test/scaffolding.dart';

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
        check(res.status).equals(HttpStatusCode.ok);
      });

      test('allows request when Content-Length is below limit', () async {
        final res = await app(
          _makeRequest(
            body: _bodyOfSize(50),
            headers: [const .contentLength(50)],
          ),
        );
        check(res.status).equals(HttpStatusCode.ok);
      });

      test('rejects request when Content-Length exceeds limit', () async {
        final res = await app(
          _makeRequest(
            body: _bodyOfSize(200),
            headers: [const .contentLength(200)],
          ),
        );
        check(res.status).equals(HttpStatusCode.contentTooLarge);
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

        check(bodyRead).isFalse();
      });
    });

    group('stream counting (chunked / no Content-Length)', () {
      test('allows body exactly at limit', () async {
        final res = await app(_makeRequest(body: _bodyOfSize(100)));
        check(res.status).equals(HttpStatusCode.ok);
      });

      test('allows body below limit', () async {
        final res = await app(_makeRequest(body: _bodyOfSize(42)));
        check(res.status).equals(HttpStatusCode.ok);
      });

      test('rejects body exceeding limit in a single chunk', () async {
        final res = await app(_makeRequest(body: _bodyOfSize(101)));
        check(res.status).equals(HttpStatusCode.contentTooLarge);
      });

      test('rejects body exceeding limit across multiple chunks', () async {
        // 3 chunks × 40 bytes = 120 bytes total > 100
        final res = await app(
          _makeRequest(body: _chunkedBody([40, 40, 40])),
        );
        check(res.status).equals(HttpStatusCode.contentTooLarge);
      });

      test('allows body within limit split across multiple chunks', () async {
        // 3 chunks × 30 bytes = 90 bytes < 100
        final res = await app(
          _makeRequest(body: _chunkedBody([30, 30, 30])),
        );
        check(res.status).equals(HttpStatusCode.ok);
      });
    });

    group('consumers that set handlers after listen', () {
      // No Content-Length, so the limit is enforced while reading.
      final consumers = <String, Future<void> Function(Request)>{
        'cast (as in rawJson)': (req) =>
            utf8.decoder.bind(req.cast<List<int>>()).join(),
        'drain': (req) => req.drain<void>(),
        'await for': (req) async {
          await for (final _ in req) {}
        },
        'listen with a one-argument onError': (req) {
          final done = Completer<void>();
          req.listen(
            (_) {},
            // A one-argument handler on purpose: it must still get the error.
            // ignore: unnecessary_lambdas
            onError: (Object error) => done.completeError(error),
            onDone: () {
              if (!done.isCompleted) done.complete();
            },
          );
          return done.future;
        },
      };

      for (final MapEntry(key: name, value: consume) in consumers.entries) {
        test('$name gets 413', () async {
          final limitedApp = IonRouter()
            ..use(Middlewares.bodyLimit(100))
            ..post('/upload', (req) async {
              await consume(req);
              return .text('ok');
            });

          final res = await Future.value(
            limitedApp(_makeRequest(body: _chunkedBody([40, 40, 40]))),
          ).timeout(const Duration(seconds: 2));
          check(res.status).equals(HttpStatusCode.contentTooLarge);
        });

        test('$name reads a body within the limit', () async {
          final limitedApp = IonRouter()
            ..use(Middlewares.bodyLimit(100))
            ..post('/upload', (req) async {
              await consume(req);
              return .text('ok');
            });

          final res = await Future.value(
            limitedApp(_makeRequest(body: _chunkedBody([30, 30, 30]))),
          ).timeout(const Duration(seconds: 2));
          check(res.status).equals(HttpStatusCode.ok);
        });
      }
    });

    test('multipart body without Content-Length over the limit gets 413', () {
      final multipartApp = IonRouter()
        ..use(Middlewares.bodyLimit(1000))
        ..post('/upload', (req) async {
          final form = await req.multipart();
          await form.clean();
          return .text('ok');
        });

      Future<Response> upload(int size) async {
        final body = utf8.encode(
          '--b\r\n'
          'Content-Disposition: form-data; name="file"; filename="a.bin"\r\n'
          '\r\n'
          '${'x' * size}\r\n'
          '--b--\r\n',
        );
        return multipartApp(
          _makeRequest(
            body: Stream.fromIterable([
              for (var i = 0; i < body.length; i += 100)
                Uint8List.fromList(
                  body.sublist(i, (i + 100).clamp(0, body.length)),
                ),
            ]),
            headers: [const .contentType('multipart/form-data; boundary=b')],
          ),
        );
      }

      return Future.wait([
        upload(5000).then((res) {
          check(res.status).equals(HttpStatusCode.contentTooLarge);
        }),
        upload(100).then((res) {
          check(res.status).equals(HttpStatusCode.ok);
        }),
      ]);
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
        check(res.status).equals(HttpStatusCode.contentTooLarge);
        check(res.bodyText).equals('too big');
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
        check(res.status).equals(HttpStatusCode.contentTooLarge);
        check(res.bodyText).equals('too big');
      });
    });
  });
}

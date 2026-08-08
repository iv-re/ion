import 'package:ion_router/ion_router.dart';
import 'package:ion_web/ion_web.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('RequestId Middleware', () {
    test(
      'generates request ID and adds X-Request-Id header when absent',
      () async {
        String? capturedId;

        final app = IonRouter()
          ..use(Middlewares.requestId())
          ..get('/test', (req) {
            capturedId = req.ctx.requestId;
            return Response.text('ok');
          });

        final response = await makeRequest(app, path: '/test');
        expect(response, isA<Response>());

        final header = response.headers.firstWhere(
          (h) => h.name == 'X-Request-Id',
        );
        expect(header.value, isNotEmpty);
        expect(header.value, equals(capturedId));
      },
    );

    test('preserves existing X-Request-Id header from client', () async {
      const existingId = 'client-provided-id-12345';
      String? capturedId;

      final app = IonRouter()
        ..use(Middlewares.requestId())
        ..get('/test', (req) {
          capturedId = req.ctx.requestId;
          return Response.text('ok');
        });

      final response = await makeRequest(
        app,
        path: '/test',
        headers: [const TestHeader('X-Request-Id', existingId)],
      );

      final header = response.headers.firstWhere(
        (h) => h.name == 'X-Request-Id',
      );
      expect(header.value, equals(existingId));
      expect(capturedId, equals(existingId));
    });

    test('supports custom headerName and idGenerator', () async {
      final app = IonRouter()
        ..use(
          Middlewares.requestId(
            headerName: 'X-Trace-Id',
            idGenerator: () => 'custom-id-999',
          ),
        )
        ..get('/test', (req) {
          return Response.text('ok');
        });

      final response = await makeRequest(app, path: '/test');

      final header = response.headers.firstWhere(
        (h) => h.name == 'X-Trace-Id',
      );
      expect(header.value, equals('custom-id-999'));
    });
  });
}

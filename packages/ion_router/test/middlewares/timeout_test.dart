import 'dart:async';

import 'package:checks/checks.dart';
import 'package:ctx/ctx.dart';
import 'package:ion_router/ion_router.dart';
import 'package:ion_web/ion_web.dart';
import 'package:test/scaffolding.dart';

Request _makeRequest(String path) {
  return Request(
    const Stream.empty(),
    method: .get,
    uri: .parse('http://localhost$path'),
    version: .http11,
    headers: TypedHeaders([]),
  );
}

void main() {
  group('Timeout Middleware', () {
    test('passes fast request through without timing out', () async {
      final app = IonRouter()
        ..use(Middlewares.timeout(const Duration(milliseconds: 200)))
        ..get('/fast', (req) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return .text('ok');
        });

      final res = await app(_makeRequest('/fast'));
      check(res.status).equals(HttpStatusCode.ok);
    });

    test('returns 504 Gateway Timeout when request exceeds duration', () async {
      final app = IonRouter()
        ..use(Middlewares.timeout(const Duration(milliseconds: 50)))
        ..get('/slow', (req) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return .text('should not reach');
        });

      final res = await app(_makeRequest('/slow'));
      check(res.status).equals(HttpStatusCode.gatewayTimeout);
    });

    test('uses custom onTimeout callback when provided', () async {
      final app = IonRouter()
        ..use(
          Middlewares.timeout(
            const Duration(milliseconds: 50),
            onTimeout: (req) => .text(
              'custom timeout',
              status: .requestTimeout,
            ),
          ),
        )
        ..get('/slow', (req) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return .text('late');
        });

      final res = await app(_makeRequest('/slow'));
      check(res.status).equals(HttpStatusCode.requestTimeout);
    });

    test('populates context deadline for inner handlers', () async {
      DateTime? innerDeadline;

      final app = IonRouter()
        ..use(Middlewares.timeout(const Duration(seconds: 5)))
        ..get('/check', (req) async {
          innerDeadline = req.ctx.deadline;
          return .text('ok');
        });

      final start = DateTime.now();
      final res = await app(_makeRequest('/check'));
      check(res.status).equals(HttpStatusCode.ok);
      check(innerDeadline).isNotNull();
      check(
        innerDeadline!.difference(start).inSeconds,
      ).isGreaterOrEqual(4);
    });

    test(
      'notifies inner handler via req.ctx.done when timeout occurs',
      () async {
        var innerCtxDone = false;

        final app = IonRouter()
          ..use(Middlewares.timeout(const Duration(milliseconds: 50)))
          ..get('/listen-done', (req) async {
            unawaited(req.ctx.done.then((_) => innerCtxDone = true));
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return .text('late');
          });

        final res = await app(_makeRequest('/listen-done'));
        check(res.status).equals(HttpStatusCode.gatewayTimeout);
        check(innerCtxDone).isTrue();
      },
    );

    test(
      'triggers 504 when inner handler throws ContextTimeoutException',
      () async {
        final app = IonRouter()
          ..use(Middlewares.timeout(const Duration(seconds: 5)))
          ..get('/timeout-exception', (req) async {
            throw const ContextTimeoutException();
          });

        final res = await app(_makeRequest('/timeout-exception'));
        check(res.status).equals(HttpStatusCode.gatewayTimeout);
      },
    );
  });
}

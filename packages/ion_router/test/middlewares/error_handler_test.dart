import 'package:ctx/ctx.dart';
import 'package:ion_router/ion_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sl/sl.dart';
import 'package:test/test.dart';

import 'utils.dart';

class MockLogHandler extends Mock implements LogHandler {
  MockLogHandler() {
    when(() => enabled(any(), any())).thenReturn(true);
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(Context.current);
    registerFallbackValue(LogLevel.error);
    registerFallbackValue(
      LogRecord(level: .error, message: '', time: .now(), attrs: const []),
    );
  });

  group('ErrorHandler Middleware', () {
    late MockLogHandler handler;
    late Logger logger;

    setUp(() {
      handler = MockLogHandler();
      logger = Logger(handler: handler);
    });

    test('passes through when no exception occurs', () async {
      final app = IonRouter()
        ..use(Middlewares.errorHandler(logger: logger))
        ..get('/test', (req) => .text('ok'));

      final res = await makeRequest(app, path: '/test');
      expect(res.status.value, equals(200));

      verifyNever(() => handler.handle(any(), any()));
    });

    test('catches unhandled exception and returns 500', () async {
      final app = IonRouter()
        ..use(Middlewares.errorHandler(logger: logger))
        ..get('/error', (req) => throw Exception('something went wrong'));

      final res = await makeRequest(app, path: '/error');
      expect(res.status.value, equals(500));

      final rec = handler.capturedRecord;
      expect(rec.level, equals(LogLevel.error));
      expect(rec.message, equals('unhandled exception in request'));
      expect(rec.attrs.any((a) => a.key == 'error'), isTrue);
    });

    test('delegates to custom onError handler', () async {
      final app = IonRouter()
        ..use(
          Middlewares.errorHandler(
            logger: logger,
            onError: (req, error, stackTrace) {
              if (error is FormatException) {
                return const .status(.badRequest);
              }
              return const .status(.internalServerError);
            },
          ),
        )
        ..get(
          '/custom-error',
          (req) => throw const FormatException('invalid format'),
        );

      final res = await makeRequest(app, path: '/custom-error');
      expect(res.status.value, equals(400));

      verifyNever(() => handler.handle(any(), any()));
    });
  });
}

extension on MockLogHandler {
  LogRecord get capturedRecord {
    return verify(() => handle(any(), captureAny())).captured.single
        as LogRecord;
  }
}

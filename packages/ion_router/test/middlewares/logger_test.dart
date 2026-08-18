import 'package:checks/checks.dart';
import 'package:ctx/ctx.dart';
import 'package:ion_router/ion_router.dart';
import 'package:ion_web/ion_web.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sl/sl.dart';
import 'package:test/scaffolding.dart';

import 'utils.dart';

class MockLogHandler extends Mock implements LogHandler {
  MockLogHandler() {
    when(() => enabled(any(), any())).thenReturn(true);
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(Context.current);
    registerFallbackValue(LogLevel.info);
    registerFallbackValue(
      LogRecord(level: .info, message: '', time: .now(), attrs: const []),
    );
  });

  group('Logger Middleware', () {
    late MockLogHandler handler;
    late Logger logger;

    setUp(() {
      handler = MockLogHandler();
      logger = Logger(handler: handler);
    });

    test('logs HTTP request details with info level for 2xx status', () async {
      final app = IonRouter()
        ..use(Middlewares.logger(logger: logger))
        ..get('/test', (req) => .text('ok'));

      final res = await makeRequest(app, path: '/test');
      check(res).isA<Response>();

      final rec = handler.capturedRecord;

      check(rec.level).equals(LogLevel.info);
      check(rec.message).equals('request processed');

      final http = rec.attrs.get<LogGroupAttr>('http');
      check(http.get<LogStringAttr>('method').value).equals('GET');
      check(http.get<LogStringAttr>('path').value).equals('/test');
      check(http.get<LogIntAttr>('status').value).equals(200);
      check(http.get<LogIntAttr>('duration_ms').value).isA<int>();
      check(http.get<LogIntAttr>('bytes').value).equals(2);
    });

    test('logs with warn level for 4xx status', () async {
      final app = IonRouter()
        ..use(Middlewares.logger(logger: logger))
        ..get('/404', (req) => const .status(.notFound));

      await makeRequest(app, path: '/404');

      check(handler.capturedRecord.level).equals(LogLevel.warn);
    });

    test('logs with error level for 5xx status', () async {
      final app = IonRouter()
        ..use(Middlewares.logger(logger: logger))
        ..get(
          '/500',
          (req) => const .status(.internalServerError),
        );

      await makeRequest(app, path: '/500');

      check(handler.capturedRecord.level).equals(LogLevel.error);
    });
  });
}

extension on MockLogHandler {
  LogRecord get capturedRecord {
    return verify(() => handle(any(), captureAny())).captured.single
        as LogRecord;
  }
}

extension LogAttrsFindX on List<LogAttr> {
  T get<T extends LogAttr>(String key) {
    return firstWhere((a) => a.key == key) as T;
  }
}

extension LogGroupFindX on LogGroupAttr {
  T get<T extends LogAttr>(String key) => values.get<T>(key);
}

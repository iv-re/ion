import 'package:ctx/ctx.dart';
import 'package:ion_router/ion_router.dart';
import 'package:ion_web/ion_web.dart';
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
      expect(res, isA<Response>());

      final rec = handler.capturedRecord;

      expect(rec.level, equals(LogLevel.info));
      expect(rec.message, equals('request processed'));

      final http = rec.attrs.get<LogGroupAttr>('http');
      expect(http.get<LogStringAttr>('method').value, equals('GET'));
      expect(http.get<LogStringAttr>('path').value, equals('/test'));
      expect(http.get<LogIntAttr>('status').value, equals(200));
      expect(http.get<LogIntAttr>('duration_ms').value, isA<int>());
      expect(http.get<LogIntAttr>('bytes').value, equals(2));
    });

    test('logs with warn level for 4xx status', () async {
      final app = IonRouter()
        ..use(Middlewares.logger(logger: logger))
        ..get('/404', (req) => const .status(.notFound));

      await makeRequest(app, path: '/404');

      expect(handler.capturedRecord.level, equals(LogLevel.warn));
    });

    test('logs with error level for 5xx status', () async {
      final app = IonRouter()
        ..use(Middlewares.logger(logger: logger))
        ..get(
          '/500',
          (req) => const .status(.internalServerError),
        );

      await makeRequest(app, path: '/500');

      expect(handler.capturedRecord.level, equals(LogLevel.error));
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

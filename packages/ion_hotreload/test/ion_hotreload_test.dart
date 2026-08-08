import 'package:ion_hotreload/ion_hotreload.dart';
import 'package:ion_web/ion_web.dart';
import 'package:test/test.dart';

void main() {
  group('hotHandler', () {
    test('delegates requests to the initial handler', () async {
      var buildCount = 0;

      Handler app() {
        buildCount++;
        return (req) => .text('build_$buildCount');
      }

      final handler = hotHandler(app);
      expect(buildCount, equals(1));

      final request = Request(
        const Stream.empty(),
        method: .get,
        uri: .parse('http://localhost/test'),
        version: .http11,
        headers: TypedHeaders([]),
      );

      final response = await handler(request);
      expect(response, isA<Response>());
      expect(response.status, equals(HttpStatusCode.ok));
    });
  });
}

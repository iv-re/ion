import 'package:ion_hotreload/ion_hotreload.dart';
import 'package:ion_web/ion_web.dart';
import 'package:sl/sl.dart';

Handler _app() {
  return (Request req) {
    return .text('Hello from ion_web with Hot Reload!');
  };
}

void main() async {
  final logger = Logger(handler: LogTextHandler(theme: .ansi));

  final server = await IonServer.serve(
    hotHandler(
      _app,
      logger: logger.withAttrs([const .string('component', 'hot_reload')]),
    ),
    address: .loopbackIPv4,
    port: 8080,
    logger: logger,
  );

  print('Server listening on http://${server.address.host}:${server.port}');
}

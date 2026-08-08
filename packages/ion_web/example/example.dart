import 'package:ion_web/ion_web.dart';
import 'package:sl/sl.dart';

Future<void> main() async {
  final logger = Logger(handler: LogTextHandler(theme: .ansi));

  final server = await IonServer.serve(
    (req) {
      return .text('OK');
    },
    address: .loopbackIPv4,
    port: 3000,
    shared: true,
    logger: logger.withAttrs([const .string('component', 'ion')]),
  );

  logger.info(
    'Server listening on http://${server.address.host}:${server.port}',
  );
}

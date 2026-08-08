# ion_web

HTTP/1.1 server and web engine for Dart.

## Usage

```dart
import 'package:ion_web/ion_web.dart';

Future<void> main() async {
  final server = await IonServer.serve(
    (req) => .text('Hello World'),
    address: .loopbackIPv4,
    port: 8080,
  );

  print('Server listening on http://${server.address.host}:${server.port}');
}
```
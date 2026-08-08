# ion_hotreload

Hot reload support for `ion_web` applications.

## Usage

Wrap your handler factory function with `hotHandler`:

```dart
import 'package:ion_hotreload/ion_hotreload.dart';
import 'package:ion_router/ion_router.dart';
import 'package:ion_web/ion_web.dart';

Future<void> main() async {
  final server = await IonServer.serve(
    hotHandler(_app),
    address: .loopbackIPv4,
    port: 8080,
  );
}

Handler _app() {
  final app = Router();
  // setup routes and middleware...
  return app;
}
```

## Running

To enable hot reloading, run your application with `--enable-vm-service` (or start it in debug mode in your IDE):

```bash
dart run --enable-vm-service bin/server.dart
```

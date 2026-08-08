import 'dart:async';

import 'package:ion_hotreload/src/hot_reloader.dart';
import 'package:ion_web/ion_web.dart';
import 'package:sl/sl.dart';

/// Creates a [Handler] with hot reloading capabilities from the provided
/// [factory].
///
/// In debug mode, [hotHandler] listens for source changes, re-executes
/// [factory] to update the active handler, and invokes [onReload].
///
/// In release mode, [hotHandler] returns the handler built by [factory].
Handler hotHandler(
  Handler Function() factory, {
  Logger? logger,
  FutureOr<void> Function()? onReload,
  List<String> watchPaths = const ['lib', 'bin', 'example', 'examples'],
}) {
  var currentHandler = factory();

  if (const bool.fromEnvironment('dart.vm.product')) {
    return currentHandler;
  }

  unawaited(
    HotReloader.listen(
      watchPaths: watchPaths,
      logger: logger,
      onReloadTriggered: () async {
        currentHandler = factory();
        await onReload?.call();
      },
    ),
  );

  return (req) => currentHandler(req);
}

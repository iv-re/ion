import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:sl/sl.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';
import 'package:watcher/watcher.dart';

/// Manages hot reloading by connecting to the Dart VM Service
/// and watching project files for changes.
class HotReloader {
  HotReloader._(this._vmService, this._subscriptions, this._logger);

  final VmService _vmService;
  final List<StreamSubscription<WatchEvent>> _subscriptions;
  final Logger? _logger;

  /// Listens to file changes and triggers hot reloads via VM Service protocol
  /// if active.
  ///
  /// Returns `null` if Dart VM Service is not enabled (e.g., in production).
  static Future<HotReloader?> listen({
    required FutureOr<void> Function() onReloadTriggered,
    Logger? logger,
    List<String> watchPaths = const ['lib', 'bin', 'example', 'examples'],
    Duration debounceDuration = const Duration(milliseconds: 100),
  }) async {
    final info = await developer.Service.getInfo();
    final serviceUri = info.serverUri;
    if (serviceUri == null) {
      return null;
    }

    logger?.info('connecting to VM Service');

    try {
      final wsUri = _convertToWebSocketUrl(serviceUri);
      final vmService = await vmServiceConnectUri(wsUri.toString());
      logger?.info('connected to VM Service');

      Timer? debounceTimer;
      var isReloading = false;

      Future<void> triggerReload() async {
        if (isReloading) return;
        isReloading = true;

        try {
          final stopwatch = Stopwatch()..start();
          final vm = await vmService.getVM();
          final mainIsolateId = vm.isolates?.firstOrNull?.id;

          if (mainIsolateId == null) {
            logger?.warn('no active isolate found for hot reload');
            return;
          }

          final report = await vmService.reloadSources(mainIsolateId);
          stopwatch.stop();

          if (report.success == true) {
            logger?.info('reloaded in ${stopwatch.elapsedMilliseconds}ms');
            await onReloadTriggered();
          } else {
            final noticesRaw = report.json?['notices'] as List?;
            final notices =
                noticesRaw
                    ?.map((n) => n is Map ? n['message']?.toString() : null)
                    .whereType<String>()
                    .where((m) => m.isNotEmpty)
                    .join('; ') ??
                '';

            final reason = notices.isNotEmpty ? notices : 'structural changes';
            logger?.error(
              'hot reload was rejected ($reason). '
              'Please restart the server process to apply changes.',
            );
          }
        } catch (e, st) {
          logger?.error(
            'failed to perform hot reload',
            attrs: [.error(e), .stackTrace(st)],
          );
        } finally {
          isReloading = false;
        }
      }

      void onFileEvent(WatchEvent event) {
        if (!event.path.endsWith('.dart')) return;

        debounceTimer?.cancel();
        debounceTimer = Timer(debounceDuration, () {
          unawaited(triggerReload());
        });
      }

      final subscriptions = <StreamSubscription<WatchEvent>>[];
      for (final path in watchPaths) {
        if (Directory(path).existsSync()) {
          final watcher = DirectoryWatcher(path);
          subscriptions.add(watcher.events.listen(onFileEvent));
        }
      }

      return HotReloader._(vmService, subscriptions, logger);
    } catch (e, st) {
      logger?.error(
        'failed to initialize HotReloader',
        attrs: [.error(e), .stackTrace(st)],
      );
      return null;
    }
  }

  /// Stops watching files and disposes of the VM Service connection.
  Future<void> stop() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    await _vmService.dispose();
    _logger?.info('HotReloader stopped');
  }

  static Uri _convertToWebSocketUrl(Uri uri) {
    final pathSegments = [...uri.pathSegments.where((s) => s.isNotEmpty), 'ws'];
    return uri.replace(
      scheme: uri.scheme == 'https' ? 'wss' : 'ws',
      pathSegments: pathSegments,
    );
  }
}

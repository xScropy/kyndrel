import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/app.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/app/licences.dart';
import 'package:kyndrel/app/media_session_sync.dart';
import 'package:kyndrel/app/perf_log.dart';
import 'package:kyndrel/core/app_info.dart';
import 'package:kyndrel/core/logging/app_log.dart';
import 'package:kyndrel/core/logging/crash_monitor.dart';
import 'package:kyndrel/core/platform/media_session.dart';
import 'package:kyndrel/core/platform/mpris.dart';
import 'package:kyndrel/core/platform/window_service.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/features/scripts/script_manager.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main(List<String> args) async {
  // Resolve relative paths now: the working directory changes during
  // start-up (libmpv/GTK end up in /tmp on Linux).
  final launch = LaunchOptions.parse(
    args,
    workingDirectory: Directory.current.path,
  );
  PerfLog.enabled = launch.perfLog;
  PerfLog.mark('main');
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledLicences();
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    title: 'Kyndrel',
    size: Size(1280, 720),
    minimumSize: Size(720, 405),
    center: true,
    backgroundColor: Color(0xFF0B0B0D),
    // Frameless: Kyndrel draws its own title bar and window buttons.
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  final window = await WindowManagerService.create();
  final settings = await SettingsRepository.create();
  final cacheDir = await getApplicationCacheDirectory();
  final supportDir = await getApplicationSupportDirectory();
  // Log file and crash detection (task 5.7). The monitor reads what the
  // previous session left before this one writes anything.
  final logsDir = Directory('${supportDir.path}${Platform.pathSeparator}logs');
  final appLog = AppLog(directory: logsDir);
  final crashes = CrashMonitor(logsDir, appLog)..start();
  appLog.info(
    'app',
    '$appName $appVersion on ${Platform.operatingSystem} '
        '${Platform.operatingSystemVersion}',
  );
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    crashes.recordError(details.exception, details.stack, source: 'flutter');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    crashes.recordError(error, stack);
    return true;
  };
  final print = debugPrint;
  debugPrint = (message, {wrapWidth}) {
    print(message, wrapWidth: wrapWidth);
    if (message != null) appLog.debug('app', message);
  };
  window.onClose(() async {
    appLog.info('app', 'Closing');
    crashes.cleanExit();
  });

  final mediaSession = Platform.isLinux
      ? await MprisMediaSession.start()
      : platformMediaSession();

  runApp(
    ProviderScope(
      overrides: [
        windowServiceProvider.overrideWithValue(window),
        appLogProvider.overrideWithValue(appLog),
        crashMonitorProvider.overrideWithValue(crashes),
        settingsRepositoryProvider.overrideWithValue(settings),
        appCacheDirProvider.overrideWithValue(cacheDir),
        mediaSessionProvider.overrideWithValue(mediaSession),
        scriptsDefaultFolderProvider.overrideWithValue(
          '${supportDir.path}${Platform.pathSeparator}scripts',
        ),
      ],
      child: KyndrelApp(launch: launch),
    ),
  );
}

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/app.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/app/media_session_sync.dart';
import 'package:kyndrel/app/perf_log.dart';
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
  final launch = LaunchOptions.parse(args);
  PerfLog.enabled = launch.perfLog;
  PerfLog.mark('main');
  WidgetsFlutterBinding.ensureInitialized();
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
  final mediaSession = Platform.isLinux
      ? await MprisMediaSession.start()
      : platformMediaSession();

  runApp(
    ProviderScope(
      overrides: [
        windowServiceProvider.overrideWithValue(window),
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

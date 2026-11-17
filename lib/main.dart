import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/app.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/core/platform/window_service.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main(List<String> args) async {
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

  runApp(
    ProviderScope(
      overrides: [
        windowServiceProvider.overrideWithValue(window),
        settingsRepositoryProvider.overrideWithValue(settings),
        appCacheDirProvider.overrideWithValue(cacheDir),
      ],
      child: KyndrelApp(launch: LaunchOptions.parse(args)),
    ),
  );
}

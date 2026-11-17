import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/app.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    title: 'Kyndrel',
    size: Size(1280, 720),
    minimumSize: Size(480, 270),
    center: true,
    backgroundColor: Color(0xFF0B0B0D),
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    ProviderScope(
      child: KyndrelApp(initialSource: args.isEmpty ? null : args.first),
    ),
  );
}

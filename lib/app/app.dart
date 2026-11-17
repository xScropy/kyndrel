import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/features/playback/player_screen.dart';
import 'package:material_ui/material_ui.dart';

class KyndrelApp extends StatelessWidget {
  const new({this.launch = const LaunchOptions(), super.key});

  final LaunchOptions launch;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kyndrel',
      debugShowCheckedModeBanner: false,
      theme: KyndrelTheme.dark(),
      themeMode: ThemeMode.dark,
      home: PlayerScreen(
        initialSource: launch.source,
        showDiagnostics: launch.showDiagnostics,
      ),
    );
  }
}

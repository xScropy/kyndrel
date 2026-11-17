import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/spike/playback_spike_page.dart';
import 'package:material_ui/material_ui.dart';

class KyndrelApp extends StatelessWidget {
  const new({this.initialSource, super.key});

  /// File path or URL passed on the command line, if any.
  final String? initialSource;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kyndrel',
      debugShowCheckedModeBanner: false,
      theme: KyndrelTheme.dark(),
      darkTheme: KyndrelTheme.dark(),
      themeMode: ThemeMode.dark,
      // Phase 0 spike. Replaced by the real player screen in Phase 1.
      home: PlaybackSpikePage(initialSource: initialSource),
    );
  }
}

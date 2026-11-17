import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/app/player_page.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

class KyndrelApp extends ConsumerWidget {
  const new({this.launch = const LaunchOptions(), super.key});

  final LaunchOptions launch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(settingsProvider.select((s) => s.language));
    return MaterialApp(
      title: 'Kyndrel',
      debugShowCheckedModeBanner: false,
      theme: KyndrelTheme.dark(),
      themeMode: ThemeMode.dark,
      locale: L10n.localeFor(language),
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: L10n.delegates,
      home: PlayerPage(launch: launch),
    );
  }
}

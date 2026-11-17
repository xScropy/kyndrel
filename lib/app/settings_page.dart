import 'package:flutter/services.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/app_info.dart';
import 'package:kyndrel/core/ui/settings_widgets.dart';
import 'package:kyndrel/features/effects/effects_dialog.dart';
import 'package:kyndrel/features/scripts/scripts_settings.dart';
import 'package:kyndrel/features/settings/settings_sections.dart';
import 'package:kyndrel/features/translate/translate_settings.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the settings page (task 5.1).
Future<void> showSettingsPage(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));

/// All settings in one page with a section list on the left. Each feature
/// supplies its own section; this page (in the app shell) puts them
/// together.
class SettingsPage extends StatefulWidget {
  const new({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _index = 0;

  static final sections = <(String, IconData, List<Widget>)>[
    ('Playback', Icons.play_circle_outline, const [PlaybackSettings()]),
    (
      'Subtitles',
      Icons.closed_caption_outlined,
      const [SubtitleSettings(), TranslateSettings()],
    ),
    (
      'Audio',
      Icons.graphic_eq,
      const [
        AudioSettings(),
        SettingsSection(title: 'Effects', children: [AudioEffectsSection()]),
      ],
    ),
    (
      'Video',
      Icons.high_quality_outlined,
      const [
        SettingsSection(title: 'Picture', children: [VideoEffectsSection()]),
      ],
    ),
    ('Shortcuts', Icons.keyboard_outlined, const [ShortcutSettings()]),
    ('Library', Icons.video_library_outlined, const [LibrarySettings()]),
    ('Appearance', Icons.palette_outlined, const [AppearanceSettings()]),
    ('Language', Icons.language, const [LanguageSettings()]),
    ('Advanced', Icons.tune, const [AdvancedSettings(), ScriptsSettings()]),
    ('About', Icons.info_outline, const [AboutSection()]),
  ];

  @override
  Widget build(BuildContext context) {
    final current = sections[_index];
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Scaffold(
        backgroundColor: KyndrelColors.background,
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: KyndrelColors.background,
        ),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 220,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final (i, s) in sections.indexed)
                    ListTile(
                      key: Key('settings-section-${s.$1}'),
                      leading: Icon(s.$2, size: 20),
                      title: Text(s.$1),
                      selected: i == _index,
                      selectedColor: KyndrelColors.accent,
                      selectedTileColor: KyndrelColors.rowActive,
                      onTap: () => setState(() => _index = i),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1, color: KyndrelColors.panelBorder),
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    key: ValueKey(current.$1),
                    padding: const EdgeInsets.all(28),
                    children: current.$3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Version and licences (5.8 adds the full list).
class AboutSection extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'About',
      children: [
        const ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('$appName $appVersion'),
          subtitle: Text('GPL-3.0 · $appRepository'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('settings-licenses'),
            onPressed: () => showLicensePage(
              context: context,
              applicationName: appName,
              applicationVersion: appVersion,
            ),
            child: const Text('Open-source licences'),
          ),
        ),
      ],
    );
  }
}

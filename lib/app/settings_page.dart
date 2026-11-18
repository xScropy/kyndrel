import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/window/window_app_bar.dart';
import 'package:kyndrel/core/app_info.dart';
import 'package:kyndrel/core/ui/settings_widgets.dart';
import 'package:kyndrel/features/effects/effects_dialog.dart';
import 'package:kyndrel/features/logs/log_viewer_page.dart';
import 'package:kyndrel/features/scripts/scripts_settings.dart';
import 'package:kyndrel/features/settings/settings_sections.dart';
import 'package:kyndrel/features/translate/translate_settings.dart';
import 'package:kyndrel/features/update/update_controller.dart';
import 'package:kyndrel/l10n/l10n.dart';
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

  /// Phones (task 6.5): the list first, then one section full width.
  bool _sectionOpen = false;

  /// (stable id, label, icon, content). Ids key the tiles for tests.
  static final sections =
      <(String, String Function(AppLocalizations), IconData, List<Widget>)>[
        (
          'Playback',
          (l) => l.settingsPlayback,
          Icons.play_circle_outline,
          const [PlaybackSettings()],
        ),
        (
          'Subtitles',
          (l) => l.settingsSubtitles,
          Icons.closed_caption_outlined,
          const [SubtitleSettings(), TranslateSettings()],
        ),
        (
          'Audio',
          (l) => l.settingsAudio,
          Icons.graphic_eq,
          const [AudioSettings(), _AudioEffects()],
        ),
        (
          'Video',
          (l) => l.settingsVideo,
          Icons.high_quality_outlined,
          const [_Picture()],
        ),
        (
          'Gestures',
          (l) => l.settingsGestures,
          Icons.touch_app_outlined,
          const [GestureSettings(), PhoneSettings()],
        ),
        (
          'Shortcuts',
          (l) => l.settingsShortcuts,
          Icons.keyboard_outlined,
          const [ShortcutSettings()],
        ),
        (
          'Library',
          (l) => l.settingsLibrary,
          Icons.video_library_outlined,
          const [LibrarySettings()],
        ),
        (
          'Appearance',
          (l) => l.settingsAppearance,
          Icons.palette_outlined,
          const [AppearanceSettings()],
        ),
        (
          'Language',
          (l) => l.settingsLanguage,
          Icons.language,
          const [LanguageSettings()],
        ),
        (
          'Advanced',
          (l) => l.settingsAdvanced,
          Icons.tune,
          const [AdvancedSettings(), ScriptsSettings()],
        ),
        (
          'About',
          (l) => l.settingsAbout,
          Icons.info_outline,
          const [AboutSection()],
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final current = sections[_index];
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final list = ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final (i, s) in sections.indexed)
          ListTile(
            key: Key('settings-section-${s.$1}'),
            leading: Icon(s.$3, size: 20),
            title: Text(s.$2(context.l10n)),
            trailing: narrow ? const Icon(Icons.chevron_right, size: 20) : null,
            selected: !narrow && i == _index,
            selectedColor: KyndrelColors.accent,
            selectedTileColor: KyndrelColors.rowActive,
            onTap: () => setState(() {
              _index = i;
              _sectionOpen = true;
            }),
          ),
      ],
    );
    final content = ListView(
      key: ValueKey(current.$1),
      padding: EdgeInsets.all(narrow ? 16 : 28),
      children: current.$4,
    );
    final Widget body;
    if (!narrow) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 220, child: list),
          const VerticalDivider(width: 1, color: KyndrelColors.panelBorder),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: content,
              ),
            ),
          ),
        ],
      );
    } else if (!_sectionOpen) {
      body = list;
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: Row(
              children: [
                IconButton(
                  key: const Key('settings-back-to-sections'),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const BackButtonIcon(),
                  onPressed: () => setState(() => _sectionOpen = false),
                ),
                Expanded(
                  child: Text(
                    current.$2(context.l10n),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: content),
        ],
      );
    }
    return PopScope(
      // The system back gesture closes a section before the page.
      canPop: !narrow || !_sectionOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _sectionOpen = false);
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).maybePop(),
        },
        child: Scaffold(
          backgroundColor: KyndrelColors.background,
          appBar: WindowAppBar(title: Text(context.l10n.settings)),
          body: SafeArea(top: false, child: body),
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
      title: context.l10n.settingsAbout,
      children: [
        const ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('$appName $appVersion'),
          subtitle: Text('GPL-3.0 · $appRepository'),
        ),
        const _UpdateCheckButton(),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('settings-view-log'),
            onPressed: () => unawaited(showLogViewer(context)),
            icon: const Icon(Icons.receipt_long, size: 18),
            label: Text(context.l10n.viewLog),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const Key('settings-licenses'),
            onPressed: () => showLicensePage(
              context: context,
              applicationName: appName,
              applicationVersion: appVersion,
            ),
            child: Text(context.l10n.openSourceLicences),
          ),
        ),
      ],
    );
  }
}

class _AudioEffects extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => SettingsSection(
    title: context.l10n.settingsEffects,
    children: const [AudioEffectsSection()],
  );
}

class _Picture extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => SettingsSection(
    title: context.l10n.settingsPicture,
    children: const [VideoEffectsSection()],
  );
}

/// Settings › About › Check for updates (task 5.6). Reports "up to date"
/// and failures, which the automatic check keeps quiet; an available
/// update shows the banner on the player page.
class _UpdateCheckButton extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(updateProvider);
    final l = context.l10n;
    final message = switch (status) {
      UpdateUpToDate() => l.updateUpToDate,
      UpdateFailed(:final message) => l.updateFailed(message),
      UpdateAvailable(:final info) ||
      UpdateDownloading(:final info) => l.updateAvailable('${info.version}'),
      _ => null,
    };
    return Row(
      children: [
        TextButton.icon(
          key: const Key('settings-check-updates'),
          onPressed: status is UpdateChecking
              ? null
              : () => unawaited(
                  ref.read(updateProvider.notifier).check(manual: true),
                ),
          icon: status is UpdateChecking
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.system_update_alt, size: 18),
          label: Text(l.updateCheckNow),
        ),
        if (message != null)
          Flexible(
            child: Text(
              message,
              key: const Key('settings-update-result'),
              style: const TextStyle(color: KyndrelColors.textSecondary),
            ),
          ),
      ],
    );
  }
}

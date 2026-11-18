import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/player/mpv_options.dart';
import 'package:kyndrel/core/storage/history_repository.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/key_bindings.dart';
import 'package:kyndrel/core/ui/settings_widgets.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

class PlaybackSettings extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return SettingsSection(
      title: 'Playback',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Skip length'),
          subtitle: const Text('Back/forward buttons and ← / →'),
          trailing: DropdownButton<int>(
            key: const Key('settings-skip'),
            value: s.skipSeconds,
            dropdownColor: KyndrelColors.surface,
            items: [
              for (final v in AppSettings.skipChoices)
                DropdownMenuItem(value: v, child: Text('$v s')),
            ],
            onChanged: (v) =>
                updateSettings(ref, (x) => x.copyWith(skipSeconds: v)),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Up next countdown'),
          subtitle: const Text(
            'Seconds before the queue moves on, with Play now and Cancel',
          ),
          trailing: DropdownButton<int>(
            key: const Key('settings-up-next'),
            value: s.upNextSeconds,
            dropdownColor: KyndrelColors.surface,
            items: [
              for (final v in AppSettings.upNextChoices)
                DropdownMenuItem(
                  value: v,
                  child: Text(v == 0 ? 'Off' : '$v s'),
                ),
            ],
            onChanged: (v) =>
                updateSettings(ref, (x) => x.copyWith(upNextSeconds: v)),
          ),
        ),
        SwitchListTile(
          key: const Key('settings-next-episode'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Play the next episode'),
          subtitle: const Text(
            'Opening S01E02 queues S01E03… from the same folder',
          ),
          value: s.autoPlayNextEpisode,
          onChanged: (v) =>
              updateSettings(ref, (x) => x.copyWith(autoPlayNextEpisode: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show time remaining instead of length'),
          value: s.showRemainingTime,
          onChanged: (v) =>
              updateSettings(ref, (x) => x.copyWith(showRemainingTime: v)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Screenshot folder'),
          subtitle: Text(
            s.screenshotFolder.isEmpty
                ? defaultScreenshotFolder()
                : s.screenshotFolder,
          ),
          trailing: TextButton(
            onPressed: () async {
              final dir = await getDirectoryPath();
              if (dir != null) {
                updateSettings(ref, (x) => x.copyWith(screenshotFolder: dir));
              }
            },
            child: const Text('Change'),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include subtitles in screenshots'),
          value: s.screenshotWithSubtitles,
          onChanged: (v) => updateSettings(
            ref,
            (x) => x.copyWith(screenshotWithSubtitles: v),
          ),
        ),
      ],
    );
  }
}

class AudioSettings extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return SettingsSection(
      title: 'Volume',
      children: [
        SwitchListTile(
          key: const Key('settings-limiter'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Limiter above 100% volume'),
          subtitle: const Text('Reduces clipping when boosting up to 400%'),
          value: s.limiterEnabled,
          onChanged: (v) =>
              updateSettings(ref, (x) => x.copyWith(limiterEnabled: v)),
        ),
      ],
    );
  }
}

class SubtitleSettings extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return SettingsSection(
      title: 'Subtitles',
      children: [
        SwitchListTile(
          key: const Key('settings-autoload'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Load subtitle files next to the video'),
          subtitle: const Text(
            'Files whose name starts like the video, e.g. Film.en.srt',
          ),
          value: s.autoLoadSubtitles,
          onChanged: (v) =>
              updateSettings(ref, (x) => x.copyWith(autoLoadSubtitles: v)),
        ),
        SettingsTextField(
          key: const Key('settings-languages'),
          label: 'Online search languages',
          helper: 'Comma-separated codes, e.g. en,ar',
          value: s.subtitleLanguages,
          onChanged: (v) =>
              updateSettings(ref, (x) => x.copyWith(subtitleLanguages: v)),
        ),
        SettingsTextField(
          key: const Key('settings-api-key'),
          label: 'OpenSubtitles API key',
          helper: 'Create one at opensubtitles.com › API consumers',
          secret: true,
          value: s.openSubtitlesApiKey,
          onChanged: (v) => updateSettings(
            ref,
            (x) => x.copyWith(openSubtitlesApiKey: v.trim()),
          ),
        ),
      ],
    );
  }
}

class LibrarySettings extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return SettingsSection(
      title: 'Library & downloads',
      children: [
        SettingsTextField(
          key: const Key('settings-tmdb-key'),
          label: 'TMDB API key or read access token',
          helper:
              'For titles, posters and episode names '
              '(themoviedb.org › Settings › API)',
          secret: true,
          value: s.tmdbApiKey,
          onChanged: (v) =>
              updateSettings(ref, (x) => x.copyWith(tmdbApiKey: v.trim())),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Download folder'),
          subtitle: Text(
            s.downloadFolder.isEmpty
                ? defaultDownloadFolder()
                : s.downloadFolder,
          ),
          trailing: TextButton(
            onPressed: () async {
              final dir = await getDirectoryPath();
              if (dir != null) {
                updateSettings(ref, (x) => x.copyWith(downloadFolder: dir));
              }
            },
            child: const Text('Change'),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const Key('settings-clear-history'),
            onPressed: () =>
                unawaited(ref.read(historyRepositoryProvider).clear()),
            child: const Text('Clear watch history'),
          ),
        ),
      ],
    );
  }
}

class AppearanceSettings extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return SettingsSection(
      title: 'Appearance',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hide controls after'),
          trailing: DropdownButton<int>(
            key: const Key('settings-hide-delay'),
            value: s.controlsHideSeconds,
            dropdownColor: KyndrelColors.surface,
            items: [
              for (final v in AppSettings.hideChoices)
                DropdownMenuItem(value: v, child: Text('$v s')),
            ],
            onChanged: (v) =>
                updateSettings(ref, (x) => x.copyWith(controlsHideSeconds: v)),
          ),
        ),
        SwitchListTile(
          key: const Key('settings-osd'),
          contentPadding: EdgeInsets.zero,
          title: const Text('On-screen messages'),
          subtitle: const Text('Volume, speed and seek feedback'),
          value: s.showOsd,
          onChanged: (v) => updateSettings(ref, (x) => x.copyWith(showOsd: v)),
        ),
      ],
    );
  }
}

class LanguageSettings extends ConsumerWidget {
  const new({super.key});

  /// Language names are written in their own language, except "System".
  static const Map<String, String?> choices = {
    'system': null,
    'en': 'English',
    'ar': 'العربية',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return SettingsSection(
      title: context.l10n.settingsLanguage,
      children: [
        RadioGroup<String>(
          groupValue: s.language,
          onChanged: (v) => updateSettings(ref, (x) => x.copyWith(language: v)),
          child: Column(
            children: [
              for (final e in choices.entries)
                RadioListTile<String>(
                  key: Key('lang-${e.key}'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: e.key,
                  title: Text(e.value ?? context.l10n.languageSystem),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class AdvancedSettings extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final parsed = parseMpvOptions(s.mpvOptions);
    return SettingsSection(
      title: 'Advanced',
      children: [
        SettingsTextField(
          key: const Key('settings-mpv-options'),
          label: 'mpv options',
          helper:
              'One option per line, as in mpv.conf (e.g. cache-secs=60). '
              'New values apply at once; removed ones after a restart.',
          maxLines: 6,
          value: s.mpvOptions,
          onChanged: (v) =>
              updateSettings(ref, (x) => x.copyWith(mpvOptions: v)),
        ),
        for (final e in parsed.errors)
          Text(
            e,
            style: const TextStyle(fontSize: 12, color: KyndrelColors.error),
          ),
        SwitchListTile(
          key: const Key('settings-updates'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Check for updates'),
          subtitle: const Text('Asks GitHub for a newer release on start'),
          value: s.checkForUpdates,
          onChanged: (v) =>
              updateSettings(ref, (x) => x.copyWith(checkForUpdates: v)),
        ),
        SwitchListTile(
          key: const Key('settings-crash'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Offer to report crashes'),
          subtitle: const Text(
            'After a crash, offer a pre-filled bug report. Nothing is sent '
            'without you.',
          ),
          value: s.offerCrashReports,
          onChanged: (v) =>
              updateSettings(ref, (x) => x.copyWith(offerCrashReports: v)),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const Key('settings-reset-all'),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Reset all settings?'),
                  content: const Text(
                    'API keys, shortcuts and preferences go back to their '
                    'defaults. Your history stays.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      key: const Key('settings-reset-confirm'),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (ok ?? false) {
                updateSettings(ref, (_) => const AppSettings());
              }
            },
            child: const Text('Reset all settings'),
          ),
        ),
      ],
    );
  }
}

/// Shortcut list with click-to-rebind (task 5.1).
class ShortcutSettings extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ShortcutSettings> createState() => _ShortcutSettingsState();
}

class _ShortcutSettingsState extends ConsumerState<ShortcutSettings> {
  PlayerAction? _capturing;
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    final action = _capturing;
    if (action == null || e is! KeyDownEvent) return KeyEventResult.ignored;
    final combo = KeyCombo.fromEvent(e);
    if (combo.isModifierOnly) return KeyEventResult.handled;
    final b = ref.read(settingsProvider).keyBindings.bind(action, combo);
    updateSettings(ref, (x) => x.copyWith(keyBindings: b));
    setState(() => _capturing = null);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final bindings = ref.watch(settingsProvider.select((s) => s.keyBindings));
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: SettingsSection(
        title: 'Shortcuts',
        children: [
          const Text(
            'Click a shortcut, then press the new keys. A key already in '
            'use moves to the new action.',
            style: TextStyle(fontSize: 12, color: KyndrelColors.textSecondary),
          ),
          for (final a in PlayerAction.values)
            ListTile(
              key: Key('shortcut-${a.name}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(a.label),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    key: Key('shortcut-edit-${a.name}'),
                    onPressed: () {
                      setState(() => _capturing = a);
                      _focus.requestFocus();
                    },
                    child: Text(
                      _capturing == a
                          ? 'Press keys…'
                          : bindings.comboFor(a)?.label ?? '—',
                      style: TextStyle(
                        color: _capturing == a ? KyndrelColors.accent : null,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Default (${a.defaultCombo.label})',
                    iconSize: 16,
                    onPressed: () => updateSettings(
                      ref,
                      (x) => x.copyWith(keyBindings: x.keyBindings.reset(a)),
                    ),
                    icon: const Icon(Icons.restart_alt),
                  ),
                ],
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('shortcuts-reset'),
              onPressed: () => updateSettings(
                ref,
                (x) => x.copyWith(keyBindings: const KeyBindings()),
              ),
              child: const Text('Reset all shortcuts'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Touch gestures on the video (task 6.3).
class GestureSettings extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    SwitchListTile tile(
      String key,
      String title,
      String subtitle,
      bool value,
      AppSettings Function(AppSettings, bool) change,
    ) => SwitchListTile(
      key: Key('settings-gesture-$key'),
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: (v) => updateSettings(ref, (x) => change(x, v)),
    );
    return SettingsSection(
      title: 'Gestures',
      children: [
        tile(
          'brightness',
          'Brightness swipe',
          'Swipe up or down on the left side. Changes Kyndrel only, not the '
              'system setting.',
          s.gestureBrightness,
          (x, v) => x.copyWith(gestureBrightness: v),
        ),
        tile(
          'volume',
          'Volume swipe',
          "Swipe up or down on the right side: the phone's volume, then "
              "Kyndrel's boost up to 200 %.",
          s.gestureVolume,
          (x, v) => x.copyWith(gestureVolume: v),
        ),
        tile(
          'seek',
          'Seek swipe',
          'Swipe left or right to move through the video, with a preview.',
          s.gestureSeek,
          (x, v) => x.copyWith(gestureSeek: v),
        ),
        tile(
          'double-tap',
          'Double-tap to skip',
          'Double-tap the left or right side to go back or forward by the '
              'skip length; again to skip more. The middle plays or pauses.',
          s.gestureDoubleTap,
          (x, v) => x.copyWith(gestureDoubleTap: v),
        ),
        tile(
          'pinch',
          'Pinch to zoom',
          'Two fingers zoom the picture in and out.',
          s.gesturePinch,
          (x, v) => x.copyWith(gesturePinch: v),
        ),
        tile(
          'long-press',
          'Hold for 2× speed',
          'Press and hold the video to play twice as fast until you let go.',
          s.gestureLongPress,
          (x, v) => x.copyWith(gestureLongPress: v),
        ),
      ],
    );
  }
}

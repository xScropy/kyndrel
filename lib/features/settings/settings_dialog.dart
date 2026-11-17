import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:material_ui/material_ui.dart';

/// The settings that Phases 1–2 need (skip length, limiter, subtitles,
/// OpenSubtitles key). The full settings page is task 5.1.
Future<void> showSettingsDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const SettingsDialog());

class SettingsDialog extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  late final _apiKey = TextEditingController(
    text: ref.read(settingsProvider).openSubtitlesApiKey,
  );
  late final _tmdbKey = TextEditingController(
    text: ref.read(settingsProvider).tmdbApiKey,
  );
  late final _languages = TextEditingController(
    text: ref.read(settingsProvider).subtitleLanguages,
  );
  bool _showKey = false;

  @override
  void dispose() {
    _apiKey.dispose();
    _languages.dispose();
    _tmdbKey.dispose();
    super.dispose();
  }

  void _update(AppSettings Function(AppSettings) change) =>
      unawaited(ref.read(settingsProvider.notifier).update(change));

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const SizedBox(height: 16),
                    const Text('PLAYBACK', style: KyndrelTheme.sectionLabel),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Skip length'),
                      subtitle: const Text('Back/forward buttons and ←/→'),
                      trailing: DropdownButton<int>(
                        key: const Key('settings-skip'),
                        value: s.skipSeconds,
                        dropdownColor: KyndrelColors.surface,
                        items: [
                          for (final v in AppSettings.skipChoices)
                            DropdownMenuItem(value: v, child: Text('$v s')),
                        ],
                        onChanged: (v) =>
                            _update((x) => x.copyWith(skipSeconds: v)),
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
                          _update((x) => x.copyWith(autoPlayNextEpisode: v)),
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
                        key: const Key('settings-screenshot-folder'),
                        onPressed: () async {
                          final dir = await getDirectoryPath();
                          if (dir != null) {
                            _update((x) => x.copyWith(screenshotFolder: dir));
                          }
                        },
                        child: const Text('Change'),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Include subtitles in screenshots'),
                      value: s.screenshotWithSubtitles,
                      onChanged: (v) => _update(
                        (x) => x.copyWith(screenshotWithSubtitles: v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('AUDIO', style: KyndrelTheme.sectionLabel),
                    SwitchListTile(
                      key: const Key('settings-limiter'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Limiter above 100% volume'),
                      subtitle: const Text('Reduces clipping when boosting'),
                      value: s.limiterEnabled,
                      onChanged: (v) =>
                          _update((x) => x.copyWith(limiterEnabled: v)),
                    ),
                    const SizedBox(height: 8),
                    const Text('SUBTITLES', style: KyndrelTheme.sectionLabel),
                    SwitchListTile(
                      key: const Key('settings-autoload'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Load subtitle files next to the video',
                      ),
                      subtitle: const Text(
                        'Files whose name starts like the video, e.g. '
                        'Film.en.srt',
                      ),
                      value: s.autoLoadSubtitles,
                      onChanged: (v) =>
                          _update((x) => x.copyWith(autoLoadSubtitles: v)),
                    ),
                    TextField(
                      key: const Key('settings-languages'),
                      controller: _languages,
                      decoration: const InputDecoration(
                        labelText: 'Online search languages',
                        helperText: 'Comma-separated codes, e.g. en,ar',
                      ),
                      onChanged: (v) =>
                          _update((x) => x.copyWith(subtitleLanguages: v)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('settings-api-key'),
                      controller: _apiKey,
                      obscureText: !_showKey,
                      decoration: InputDecoration(
                        labelText: 'OpenSubtitles API key',
                        helperText:
                            'Create one at opensubtitles.com › API consumers',
                        suffixIcon: IconButton(
                          tooltip: _showKey ? 'Hide' : 'Show',
                          icon: Icon(
                            _showKey ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () => setState(() => _showKey = !_showKey),
                        ),
                      ),
                      onChanged: (v) => _update(
                        (x) => x.copyWith(openSubtitlesApiKey: v.trim()),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('LIBRARY', style: KyndrelTheme.sectionLabel),
                    TextField(
                      key: const Key('settings-tmdb-key'),
                      controller: _tmdbKey,
                      obscureText: !_showKey,
                      decoration: const InputDecoration(
                        labelText: 'TMDB API key or read access token',
                        helperText:
                            'For titles, posters and episode names '
                            '(themoviedb.org › Settings › API)',
                      ),
                      onChanged: (v) =>
                          _update((x) => x.copyWith(tmdbApiKey: v.trim())),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/settings_widgets.dart';
import 'package:kyndrel/features/scripts/script_manager.dart';
import 'package:material_ui/material_ui.dart';

/// mpv user scripts (task 4.9) for the settings page.
class ScriptsSettings extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final scripts = ref.watch(scriptManagerProvider);
    return SettingsSection(
      title: 'Scripts',
      children: [
        SwitchListTile(
          key: const Key('settings-scripts'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Load mpv scripts (Lua / JavaScript)'),
          subtitle: Text(
            'From ${scripts.folder}. Scripts can do anything mpv can: only '
            'use scripts you trust. ${scripts.loaded.length}/'
            '${scripts.found.length} loaded.',
          ),
          value: s.scriptsEnabled,
          onChanged: (v) =>
              updateSettings(ref, (x) => x.copyWith(scriptsEnabled: v)),
        ),
        if (s.scriptsEnabled)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('settings-scripts-reload'),
              onPressed: () =>
                  unawaited(ref.read(scriptManagerProvider.notifier).loadAll()),
              child: const Text('Load new scripts'),
            ),
          ),
      ],
    );
  }
}

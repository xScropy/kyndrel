import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/osd.dart';
import 'package:path/path.dart' as p;

/// Default folder for user scripts; set in `main.dart`.
final scriptsDefaultFolderProvider = Provider<String>(
  (ref) => p.join(Directory.systemTemp.path, 'kyndrel-scripts'),
);

@immutable
class ScriptsState {
  const new({this.folder = '', this.found = const [], this.loaded = const {}});

  final String folder;
  final List<String> found;

  /// Scripts already loaded into this mpv instance.
  final Set<String> loaded;
}

/// Loads mpv Lua/JavaScript user scripts from a folder (task 4.9), and shows
/// what scripts put in `user-data/kyndrel/osd`.
class ScriptManager extends Notifier<ScriptsState> {
  static const extensions = {'.lua', '.js'};

  @override
  ScriptsState build() {
    final defaultFolder = ref.read(scriptsDefaultFolderProvider);
    String folderOf(AppSettings s) =>
        s.scriptsFolder.isEmpty ? defaultFolder : s.scriptsFolder;
    final settings = ref.read(settingsProvider);
    final osd = ref
        .read(playerServiceProvider)
        .scriptOsd
        .listen((t) => ref.read(osdProvider.notifier).show(t));
    ref
      ..onDispose(osd.cancel)
      // Only the script settings matter; keep `loaded` across other changes.
      ..listen(
        settingsProvider.select((s) => (s.scriptsEnabled, folderOf(s))),
        (_, next) {
          final (enabled, folder) = next;
          state = ScriptsState(
            folder: folder,
            found: scan(folder),
            loaded: state.loaded,
          );
          if (enabled) unawaited(loadAll());
        },
      );
    final folder = folderOf(settings);
    if (settings.scriptsEnabled) {
      // State can't change during build: load right after.
      scheduleMicrotask(() => unawaited(loadAll()));
    }
    return ScriptsState(folder: folder, found: scan(folder));
  }

  static List<String> scan(String folder) {
    final dir = Directory(folder);
    if (!dir.existsSync()) return const [];
    return dir
        .listSync()
        .whereType<File>()
        .map((f) => f.path)
        .where((f) => extensions.contains(p.extension(f).toLowerCase()))
        .toList()
      ..sort();
  }

  /// Loads every script in the folder that isn't loaded yet. mpv can't
  /// unload scripts; turning scripts off takes effect after a restart.
  Future<void> loadAll() async {
    if (!ref.read(settingsProvider).scriptsEnabled) return;
    final service = ref.read(playerServiceProvider);
    final loaded = {...state.loaded};
    for (final s in scan(state.folder)) {
      if (loaded.add(s)) await service.loadScript(s);
    }
    state = ScriptsState(
      folder: state.folder,
      found: scan(state.folder),
      loaded: loaded,
    );
  }
}

final scriptManagerProvider = NotifierProvider<ScriptManager, ScriptsState>(
  ScriptManager.new,
);

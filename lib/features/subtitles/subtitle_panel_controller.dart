import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/player_providers.dart';

/// What the panel's right pane shows.
enum SubtitlePanelView { online, sync, style }

/// Null when the panel is closed (task 2.4).
class SubtitlePanelController extends Notifier<SubtitlePanelView?> {
  @override
  SubtitlePanelView? build() => null;

  // ignore: use_setters_to_change_properties, reads better at call sites
  void open([SubtitlePanelView view = SubtitlePanelView.online]) =>
      state = view;

  void close() => state = null;

  void toggle() => state == null ? open() : close();

  /// Header icons: pressing the active one goes back to online results.
  void show(SubtitlePanelView view) =>
      state = state == view ? SubtitlePanelView.online : view;
}

final subtitlePanelProvider =
    NotifierProvider<SubtitlePanelController, SubtitlePanelView?>(
      SubtitlePanelController.new,
    );

abstract final class SubtitleFileActions {
  static const extensions = [
    'srt', 'ass', 'ssa', 'vtt', 'sub', 'idx', 'sup', 'smi', 'sami', 'txt', //
    'lrc', 'mks',
  ];

  /// Picks a subtitle file and loads it as the active track (task 2.6).
  static Future<void> loadFile(WidgetRef ref) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Subtitles', extensions: extensions),
        XTypeGroup(label: 'All files'),
      ],
    );
    if (file != null) {
      await ref.read(playerServiceProvider).addSubtitle(file.path);
    }
  }
}

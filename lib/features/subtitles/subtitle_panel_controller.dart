import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/platform/device_media.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:path/path.dart' as p;

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
    'lrc', 'mks', 'zip',
  ];

  static const audioExtensions = [
    'mka', 'ac3', 'eac3', 'dts', 'aac', 'm4a', 'mp3', 'flac', 'ogg', 'opus', //
    'wav',
  ];

  /// Picks an audio file and adds it as the selected audio track (8.8).
  static Future<void> loadAudio(WidgetRef ref) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Audio', extensions: audioExtensions),
        XTypeGroup(label: 'All files'),
      ],
    );
    if (file != null) {
      await ref.read(playerServiceProvider).addAudioTrack(file.path);
    }
  }

  /// Subtitle files inside a ZIP (as subtitle sites hand them out), written
  /// to [outDir] (task 8.8). The first one found comes first.
  static List<String> unzipSubtitles(String zipPath, String outDir) {
    final archive = ZipDecoder().decodeBytes(File(zipPath).readAsBytesSync());
    final out = <String>[];
    for (final f in archive.files) {
      if (!f.isFile) continue;
      final name = p.basename(f.name);
      final ext = p.extension(name).toLowerCase().replaceFirst('.', '');
      if (ext == 'zip' || !extensions.contains(ext)) continue;
      final path = p.join(outDir, name);
      File(path)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(f.content);
      out.add(path);
    }
    // `.txt` is a subtitle format too, but in a ZIP it is usually a readme:
    // only kept when there is nothing else.
    final real = [
      for (final f in out)
        if (p.extension(f).toLowerCase() != '.txt') f,
    ];
    return real.isEmpty ? out : real;
  }

  /// Adds [path], or every subtitle inside it when it is a ZIP.
  static Future<void> _add(WidgetRef ref, String path) async {
    final service = ref.read(playerServiceProvider);
    if (p.extension(path).toLowerCase() != '.zip') {
      await service.addSubtitle(path);
      return;
    }
    final dir = p.join(
      ref.read(appCacheDirProvider).path,
      'subtitles-zip',
      p.basenameWithoutExtension(path),
    );
    final files = unzipSubtitles(path, dir);
    for (final (i, f) in files.indexed) {
      await service.addSubtitle(f, select: i == 0);
    }
  }

  /// Picks a subtitle file and loads it as the active track (task 2.6).
  static Future<void> loadFile(WidgetRef ref) async {
    // Android: the system picker, with a local copy mpv can read (7.1).
    final device = ref.read(deviceMediaProvider);
    if (device != null) {
      final path = await device.pickFileCopy();
      if (path != null) await _add(ref, path);
      return;
    }
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Subtitles', extensions: extensions),
        XTypeGroup(label: 'All files'),
      ],
    );
    if (file != null) await _add(ref, file.path);
  }
}

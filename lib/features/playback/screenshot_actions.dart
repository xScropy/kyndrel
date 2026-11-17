import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/osd.dart';
import 'package:kyndrel/core/utils/media_title.dart';
import 'package:path/path.dart' as p;

/// Saves the current frame as a PNG (task 3.8).
abstract final class ScreenshotActions {
  /// `The Matrix 01-02-03.png` for 1:02:03 into the film.
  static String fileName(String source, Duration position) {
    final title = parseMediaTitle(source);
    final name = [
      title.title,
      ?title.episode,
    ].join(' ').replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    String two(int n) => n.toString().padLeft(2, '0');
    final t =
        '${two(position.inHours)}-${two(position.inMinutes % 60)}-'
        '${two(position.inSeconds % 60)}';
    return '$name $t.png';
  }

  /// Takes the screenshot and shows where it went. Returns the path, or
  /// null if nothing is playing.
  static Future<String?> take(WidgetRef ref) async {
    final service = ref.read(playerServiceProvider);
    final source = service.state.source;
    if (source == null || !service.state.isLoaded) return null;
    final settings = ref.read(settingsProvider);
    final folder = settings.screenshotFolder.isEmpty
        ? defaultScreenshotFolder()
        : settings.screenshotFolder;
    Directory(folder).createSync(recursive: true);
    final name = fileName(source, service.state.position);
    var path = p.join(folder, name);
    // Don't overwrite an earlier shot of the same second.
    for (var i = 2; File(path).existsSync(); i++) {
      path = p.join(folder, '${p.basenameWithoutExtension(name)} ($i).png');
    }
    await service.screenshotTo(
      path,
      withSubtitles: settings.screenshotWithSubtitles,
    );
    ref
        .read(osdProvider.notifier)
        .show('Screenshot saved · ${p.basename(path)}');
    return path;
  }
}

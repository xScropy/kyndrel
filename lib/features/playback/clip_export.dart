import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/osd.dart';
import 'package:kyndrel/core/utils/media_title.dart';
import 'package:path/path.dart' as p;

/// Saves the A-B loop as a video clip or a GIF with ffmpeg (task 8.8, like
/// PotPlayer's clip export). Desktop only, when ffmpeg is installed.
abstract final class ClipExport {
  /// 12 fps, 480 px wide, with a palette made for this clip.
  static const gifFilter =
      'fps=12,scale=480:-2:flags=lanczos,split[s0][s1];'
      '[s0]palettegen[p];[s1][p]paletteuse';

  /// ffmpeg's arguments for [source] from [a] to [b] into [out]. A clip is
  /// a stream copy (instant, cut at keyframes); a GIF is 12 fps, 480 px,
  /// with its own palette.
  static List<String> argsFor({
    required String source,
    required Duration a,
    required Duration b,
    required String out,
    required bool gif,
  }) {
    String t(Duration d) => (d.inMilliseconds / 1000).toStringAsFixed(3);
    return [
      '-y',
      '-ss',
      t(a),
      '-to',
      t(b),
      '-i',
      source,
      if (gif) ...[
        '-vf',
        gifFilter,
        '-loop',
        '0',
      ] else ...[
        '-map',
        '0',
        '-c',
        'copy',
        '-avoid_negative_ts',
        'make_zero',
      ],
      out,
    ];
  }

  static bool? _haveFfmpeg;

  /// Whether `ffmpeg` runs here (looked up once).
  static Future<bool> available({
    Future<ProcessResult> Function(String, List<String>)? run,
  }) async {
    if (_haveFfmpeg != null && run == null) return _haveFfmpeg!;
    try {
      final r = await (run ?? Process.run)('ffmpeg', ['-version']);
      return _haveFfmpeg = r.exitCode == 0;
    } on ProcessException {
      return _haveFfmpeg = false;
    }
  }

  /// Exports the current A-B loop; the saved file's path, or null.
  static Future<String?> export(
    WidgetRef ref, {
    required bool gif,
    Future<ProcessResult> Function(String, List<String>)? run,
  }) async {
    final osd = ref.read(osdProvider.notifier);
    final service = ref.read(playerServiceProvider);
    final source = service.state.source;
    final a = service.tracks.loopA;
    final b = service.tracks.loopB;
    if (source == null || a == null || b == null || b <= a) {
      osd.show('Set an A-B loop first (L)');
      return null;
    }
    if (!await available(run: run)) {
      osd.show('Saving clips needs ffmpeg');
      return null;
    }
    final settings = ref.read(settingsProvider);
    final folder = settings.screenshotFolder.isEmpty
        ? defaultScreenshotFolder()
        : settings.screenshotFolder;
    await Directory(folder).create(recursive: true);
    String stamp(Duration d) =>
        '${d.inMinutes}m${(d.inSeconds % 60).toString().padLeft(2, '0')}s';
    final title = parseMediaTitle(source).title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final ext = gif ? 'gif' : _clipExtension(source);
    final out = p.join(folder, '$title ${stamp(a)}-${stamp(b)}.$ext');
    osd.show(gif ? 'Saving GIF…' : 'Saving clip…');
    final r = await (run ?? Process.run)(
      'ffmpeg',
      argsFor(source: source, a: a, b: b, out: out, gif: gif),
    );
    if (r.exitCode != 0) {
      osd.show("Couldn't save the clip");
      return null;
    }
    osd.show('Saved ${p.basename(out)}');
    return out;
  }

  /// The source's own container when stream copy can keep it.
  static String _clipExtension(String source) {
    final ext = p.extension(source).toLowerCase().replaceFirst('.', '');
    return const {'mp4', 'mkv', 'webm', 'mov', 'ts'}.contains(ext)
        ? ext
        : 'mkv';
  }
}

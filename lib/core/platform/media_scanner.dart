import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Videos or music.
enum MediaKind { video, audio }

/// One file a scan found (task 7.3). Android knows the details from
/// MediaStore; on desktop they are probed later.
@immutable
class ScannedFile {
  const new({
    required this.uri,
    required this.name,
    required this.folderPath,
    required this.kind,
    required this.size,
    required this.modified,
    this.added,
    this.duration,
    this.width,
    this.height,
    this.title,
    this.artist,
    this.album,
    this.trackNo,
    this.hasSubtitles = false,
  });

  factory fromMap(Map<Object?, Object?> m) {
    DateTime seconds(Object? v) =>
        DateTime.fromMillisecondsSinceEpoch(((v as num?) ?? 0).toInt() * 1000);
    int? positive(Object? v) {
      final n = (v as num?)?.toInt();
      return n == null || n <= 0 ? null : n;
    }

    String? text(Object? v) {
      final s = v as String?;
      return s == null || s.isEmpty ? null : s;
    }

    final ms = positive(m['durationMs']);
    return ScannedFile(
      uri: m['uri']! as String,
      name: m['name']! as String,
      folderPath: m['folderPath'] as String? ?? '',
      kind: m['kind'] == 'audio' ? MediaKind.audio : MediaKind.video,
      size: (m['size'] as num?)?.toInt() ?? 0,
      modified: seconds(m['modifiedS']),
      added: seconds(m['addedS']),
      duration: ms == null ? null : Duration(milliseconds: ms),
      width: positive(m['width']),
      height: positive(m['height']),
      title: text(m['title']),
      artist: text(m['artist']),
      album: text(m['album']),
      trackNo: positive(m['trackNo']),
      hasSubtitles: m['hasSubtitles'] == true,
    );
  }

  /// A subtitle file with the same name sits next to it (task 8.5).
  final bool hasSubtitles;

  final String uri;
  final String name;
  final String folderPath;
  final MediaKind kind;
  final int size;
  final DateTime modified;

  /// When the device added it (Android); the scan time otherwise.
  final DateTime? added;
  final Duration? duration;
  final int? width;
  final int? height;
  final String? title;
  final String? artist;
  final String? album;
  final int? trackNo;

  /// The folder's name as shown.
  String get folder {
    final name = p.basename(folderPath);
    return name.isEmpty ? folderPath : name;
  }

  /// Whether the scan already knows the details (no probe needed).
  bool get hasDetails => duration != null;
}

/// Finds the videos and music on this device (task 7.3).
abstract interface class MediaScanner {
  /// Asks for access where the OS needs it; true when something can be
  /// read.
  Future<bool> requestAccess();

  Future<List<ScannedFile>> scan();
}

/// Android: MediaStore videos and music (`library` on
/// `kyndrel/android_media`).
class AndroidMediaScanner implements MediaScanner {
  const new();

  static const _channel = MethodChannel('kyndrel/android_media');

  @override
  Future<bool> requestAccess() async =>
      await _channel.invokeMethod<bool>('requestLibraryAccess') ?? false;

  @override
  Future<List<ScannedFile>> scan() async {
    // Big phones answer in seconds; a stuck query must not hang the
    // library forever (task 8.11).
    final list = await _channel
        .invokeListMethod<Map<Object?, Object?>>('library')
        .timeout(const Duration(minutes: 2));
    return [
      for (final m in list ?? const <Map<Object?, Object?>>[])
        ScannedFile.fromMap(m),
    ];
  }
}

/// Desktop: the files under the library folders, by extension.
class FolderMediaScanner implements MediaScanner {
  new(this.folders);

  final List<String> folders;

  static const videoExtensions = {
    'mp4', 'mkv', 'avi', 'mov', 'webm', 'm4v', 'wmv', 'flv', 'mpg', //
    'mpeg', 'ts', 'm2ts', 'mts', '3gp', 'ogv', 'vob',
  };
  static const audioExtensions = {
    'mp3', 'flac', 'm4a', 'aac', 'ogg', 'opus', 'wav', 'wma', 'alac', //
    'aiff', 'aif', 'ape', 'mka',
  };

  static MediaKind? kindOf(String path) {
    final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
    if (videoExtensions.contains(ext)) return MediaKind.video;
    if (audioExtensions.contains(ext)) return MediaKind.audio;
    return null;
  }

  @override
  Future<bool> requestAccess() async => true;

  /// Subtitle files that count as "has subtitles" for a video beside them.
  static const subtitleExtensions = {'srt', 'ass', 'ssa', 'vtt', 'sub', 'sup'};

  /// Walks the folders in a background isolate, so a big library never
  /// blocks the UI (task 8.5).
  @override
  Future<List<ScannedFile>> scan() {
    final roots = folders;
    return Isolate.run(() => scanSync(roots));
  }

  /// [scan]'s work. Skips hidden folders, unreadable ones and folders with a
  /// `.nomedia` file (task 8.5), like Android does.
  static List<ScannedFile> scanSync(List<String> roots) {
    final out = <ScannedFile>[];
    final seen = <String>{};
    void walk(Directory dir) {
      List<FileSystemEntity> entries;
      try {
        entries = dir.listSync(followLinks: false);
      } on FileSystemException {
        return;
      }
      if (entries.any((e) => p.basename(e.path) == '.nomedia')) return;
      // "Film.srt", "Film.en.srt": subtitles for "Film.mkv".
      final subtitleNames = <String>[
        for (final e in entries)
          if (e is File &&
              subtitleExtensions.contains(
                p.extension(e.path).toLowerCase().replaceFirst('.', ''),
              ))
            p.basenameWithoutExtension(e.path).toLowerCase(),
      ];
      for (final e in entries) {
        if (p.basename(e.path).startsWith('.')) continue;
        if (e is Directory) {
          walk(e);
          continue;
        }
        if (e is! File || !seen.add(e.path)) continue;
        final kind = kindOf(e.path);
        if (kind == null) continue;
        final base = p.basenameWithoutExtension(e.path).toLowerCase();
        try {
          final stat = e.statSync();
          out.add(
            ScannedFile(
              uri: e.path,
              name: p.basename(e.path),
              folderPath: e.parent.path,
              kind: kind,
              size: stat.size,
              modified: stat.modified,
              hasSubtitles:
                  kind == MediaKind.video &&
                  subtitleNames.any((n) => n == base || n.startsWith('$base.')),
            ),
          );
        } on FileSystemException {
          // Gone or unreadable: skip.
        }
      }
    }

    for (final root in roots) {
      final dir = Directory(root);
      if (dir.existsSync()) walk(dir);
    }
    return out;
  }

  /// The user's Videos (Movies on macOS) and Music folders.
  static List<String> defaultFolders({Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    final home = env['USERPROFILE'] ?? env['HOME'];
    if (home == null) return const [];
    final videos = Platform.isMacOS ? 'Movies' : 'Videos';
    return [p.join(home, videos), p.join(home, 'Music')];
  }
}

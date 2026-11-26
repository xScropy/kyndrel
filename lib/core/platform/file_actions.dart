import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// Moving files to the trash, renaming and moving them (task 8.6).
///
/// Desktop only: on Android a file in MediaStore can be changed only
/// through a system confirmation, which needs native code Kyndrel doesn't
/// have yet, so the library hides these actions there.
class FileActions {
  new({
    Future<ProcessResult> Function(String, List<String>)? run,
    Map<String, String>? environment,
    String? os,
  }) : _run = run ?? Process.run,
       _env = environment ?? Platform.environment,
       _os = os ?? Platform.operatingSystem;

  final Future<ProcessResult> Function(String, List<String>) _run;
  final Map<String, String> _env;
  final String _os;

  bool get supported => _os == 'linux' || _os == 'macos' || _os == 'windows';

  /// Moves [path] to the system trash (recycle bin). Throws when it can't:
  /// a file is never deleted for good.
  Future<void> trash(String path) async {
    switch (_os) {
      case 'macos':
        final quoted = path.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
        final script =
            'tell application "Finder" to delete POSIX file '
            '"$quoted"';
        final r = await _run('osascript', ['-e', script]);
        if (r.exitCode != 0) throw FileSystemException('${r.stderr}', path);
      case 'windows':
        final command =
            'Add-Type -AssemblyName Microsoft.VisualBasic; '
            '[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile('
            "'${path.replaceAll("'", "''")}', 'OnlyErrorDialogs', "
            "'SendToRecycleBin')";
        final r = await _run('powershell', ['-NoProfile', '-Command', command]);
        if (r.exitCode != 0) throw FileSystemException('${r.stderr}', path);
      case 'linux':
        try {
          final r = await _run('gio', ['trash', path]);
          if (r.exitCode == 0) return;
        } on ProcessException {
          // No gio: the freedesktop trash by hand.
        }
        await _freedesktopTrash(path);
      default:
        throw FileSystemException('No trash on this system', path);
    }
  }

  /// The freedesktop.org trash: `~/.local/share/Trash/files` plus an info
  /// file saying where it came from, so file managers can restore it.
  Future<void> _freedesktopTrash(String path) async {
    final home = _env['HOME'];
    if (home == null) throw FileSystemException('No home folder', path);
    final data = _env['XDG_DATA_HOME'] ?? p.join(home, '.local', 'share');
    final files = Directory(p.join(data, 'Trash', 'files'));
    final info = Directory(p.join(data, 'Trash', 'info'));
    await files.create(recursive: true);
    await info.create(recursive: true);
    var name = p.basename(path);
    for (var n = 2; File(p.join(files.path, name)).existsSync(); n++) {
      name = '${p.basenameWithoutExtension(path)}.$n${p.extension(path)}';
    }
    final now = DateTime.now().toIso8601String().split('.').first;
    await File(p.join(info.path, '$name.trashinfo')).writeAsString(
      '[Trash Info]\nPath=${Uri.file(path).path}\nDeletionDate=$now\n',
    );
    await File(path).rename(p.join(files.path, name));
  }

  /// Renames [path] to [newName] in the same folder, with subtitle files
  /// of the same name ("Film.srt", "Film.en.srt"). Returns the new path.
  Future<String> rename(String path, String newName) async {
    final name = newName.trim();
    if (name.isEmpty || name.contains('/') || name.contains(r'\')) {
      throw FileSystemException('Not a file name', newName);
    }
    final dir = p.dirname(path);
    final target = p.join(dir, name);
    if (File(target).existsSync()) {
      throw FileSystemException('A file with that name exists', target);
    }
    final oldBase = p.basenameWithoutExtension(path);
    final newBase = p.basenameWithoutExtension(name);
    await File(path).rename(target);
    for (final f in Directory(dir).listSync().whereType<File>()) {
      final b = p.basename(f.path);
      if (b.startsWith('$oldBase.') && _isSubtitle(b)) {
        await f.rename(p.join(dir, '$newBase${b.substring(oldBase.length)}'));
      }
    }
    return target;
  }

  /// Moves [path] (and its subtitle files) into [folder]; copies when the
  /// folder is on another disk. Returns the new path.
  Future<String> move(String path, String folder) async {
    final target = p.join(folder, p.basename(path));
    if (File(target).existsSync()) {
      throw FileSystemException('A file with that name exists', target);
    }
    final base = p.basenameWithoutExtension(path);
    final dir = p.dirname(path);
    final subtitles = [
      for (final f in Directory(dir).listSync().whereType<File>())
        if (p.basename(f.path).startsWith('$base.') &&
            _isSubtitle(p.basename(f.path)))
          f,
    ];
    await _moveOne(File(path), target);
    for (final s in subtitles) {
      await _moveOne(s, p.join(folder, p.basename(s.path)));
    }
    return target;
  }

  static Future<void> _moveOne(File f, String target) async {
    try {
      await f.rename(target);
    } on FileSystemException {
      // Another disk: copy, then delete the original.
      await f.copy(target);
      await f.delete();
    }
  }

  static bool _isSubtitle(String name) => const {
    '.srt',
    '.ass',
    '.ssa',
    '.vtt',
    '.sub',
    '.sup',
  }.contains(p.extension(name).toLowerCase());
}

final fileActionsProvider = Provider<FileActions>((ref) => FileActions());

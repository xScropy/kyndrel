import 'dart:io';

/// Deletes the oldest sub-folders of [root] (by their newest file) until
/// the folder holds at most [limit] bytes. Folders in [keep] stay (task 8.0).
///
/// Folders are listed asynchronously, so a big cache never blocks the UI
/// isolate for long.
Future<void> trimCacheFolder(
  Directory root, {
  required int limit,
  Set<String> keep = const {},
}) async {
  if (!root.existsSync()) return;
  final folders = <(Directory, int, DateTime)>[];
  var total = 0;
  try {
    await for (final entry in root.list()) {
      if (entry is! Directory) continue;
      var size = 0;
      var newest = DateTime.fromMillisecondsSinceEpoch(0);
      await for (final f in entry.list(recursive: true)) {
        if (f is! File) continue;
        final stat = f.statSync();
        size += stat.size;
        if (stat.modified.isAfter(newest)) newest = stat.modified;
      }
      total += size;
      folders.add((entry, size, newest));
    }
  } on FileSystemException {
    return; // Changed while listing: try again next time.
  }
  folders.sort((a, b) => a.$3.compareTo(b.$3));
  for (final (dir, size, _) in folders) {
    if (total <= limit) break;
    if (keep.contains(dir.path)) continue;
    try {
      await dir.delete(recursive: true);
      total -= size;
    } on FileSystemException {
      // In use or already gone.
    }
  }
}

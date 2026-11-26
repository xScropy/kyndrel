import 'dart:io';

import 'package:kyndrel/core/utils/hashing.dart';

/// The cache key of [source]'s frames, thumbnails and storyboards (task 8.0).
///
/// A local file's key includes its size and modified time, so a file
/// replaced at the same path gets new pictures instead of the old ones.
/// Streams, `content://` URIs and missing files use the source alone.
///
/// One `stat` per source per session (remembered), so calling it on every
/// scrub move costs nothing.
String mediaCacheKey(String source) {
  final known = _keys[source];
  if (known != null) return known;
  if (_keys.length >= _maxKeys) _keys.clear();
  return _keys[source] = _keyOf(source);
}

/// Forgets remembered keys (tests, or after the library sees a file change).
void forgetMediaCacheKeys() => _keys.clear();

const _maxKeys = 256;
final _keys = <String, String>{};

String _keyOf(String source) {
  final path = localPathOf(source);
  if (path != null) {
    try {
      final stat = File(path).statSync();
      if (stat.type == FileSystemEntityType.file) {
        return fnv1a64(
          '$source|${stat.size}|${stat.modified.millisecondsSinceEpoch}',
        );
      }
    } on FileSystemException {
      // Unreadable: fall back to the source alone.
    }
  }
  return fnv1a64(source);
}

/// The file path of a local [source] (plain path or `file://`), else null.
String? localPathOf(String source) {
  if (source.startsWith('file://')) {
    final uri = Uri.tryParse(source);
    // A host (file://server/share) isn't a local path on every platform.
    if (uri == null || uri.host.isNotEmpty) return null;
    return uri.toFilePath();
  }
  if (source.contains('://')) return null;
  return source;
}

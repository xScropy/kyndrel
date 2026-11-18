import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:kyndrel/core/player/preview_thumbnailer.dart';
import 'package:kyndrel/core/utils/hashing.dart';
import 'package:path/path.dart' as p;

/// Preview frames on Android (task 6.4): `MediaMetadataRetriever` through
/// `kyndrel/frames` (MainActivity.kt). It reads `content://` files, uses
/// the hardware decoder and needs no second mpv. Same cache layout as
/// [PreviewThumbnailer]: `<cache>/previews/<hash>/<second>.jpg`.
class AndroidFrameSource implements PreviewSource {
  new({required this.cacheDir, MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('kyndrel/frames');

  /// Bigger than the desktop's: the phone preview is ~40 % of the screen.
  static const width = 480;

  final Directory cacheDir;
  final MethodChannel _channel;
  final _queue = Queue<({String source, int second, String path})>();
  final _waiting = <String, Completer<String?>>{};
  bool _busy = false;

  @override
  Duration stepFor(Duration duration) {
    final s = (duration.inSeconds / 200).ceil();
    return Duration(seconds: s < 2 ? 2 : s);
  }

  String _path(String source, int second) =>
      p.join(cacheDir.path, 'previews', fnv1a64(source), '$second.jpg');

  @override
  Future<String?> frameAt(String source, Duration at, Duration duration) {
    // Network streams: decoding a second copy costs data and time.
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Future.value();
    }
    final step = stepFor(duration).inSeconds;
    final second = (at.inSeconds ~/ step) * step;
    final path = _path(source, second);
    if (File(path).existsSync()) return Future.value(path);
    final pending = _waiting[path];
    if (pending != null) return pending.future;
    final completer = _waiting[path] = Completer<String?>();
    // Only the newest few positions matter while the finger moves.
    while (_queue.length >= 3) {
      final dropped = _queue.removeFirst();
      _waiting.remove(dropped.path)?.complete();
    }
    _queue.add((source: source, second: second, path: path));
    unawaited(_pump());
    return completer.future;
  }

  Future<void> _pump() async {
    if (_busy) return;
    _busy = true;
    try {
      while (_queue.isNotEmpty) {
        final r = _queue.removeLast();
        String? result;
        try {
          final ok = await _channel.invokeMethod<bool>('frame', {
            'source': r.source,
            'ms': r.second * 1000,
            'width': width,
            'path': r.path,
          });
          if ((ok ?? false) && File(r.path).existsSync()) result = r.path;
        } on PlatformException {
          result = null;
        } on MissingPluginException {
          result = null;
        }
        _waiting.remove(r.path)?.complete(result);
      }
    } finally {
      _busy = false;
    }
  }
}

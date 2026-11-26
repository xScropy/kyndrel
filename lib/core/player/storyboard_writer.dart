import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:image/image.dart' as img;
import 'package:kyndrel/core/player/storyboard.dart';

/// Keeps track of a storyboard being made and packs its frames into sprite
/// sheets (task 8.2). Desktop and Android grab frames differently; both
/// report them here.
///
/// - [next] gives the frame to make next: around [focus] first (where the
///   finger is), then coarse to fine ([coarseToFine]).
/// - A sheet is packed in a background isolate once all its frames are done
///   ([packEarly]), or when its level finishes. Packed frames' tiles are
///   deleted.
/// - [onChange] gets the new state after every frame and sheet.
class StoryboardWriter {
  new(Storyboard board, {this.onChange, this.packEarly = true})
    : _board = board;

  final void Function(Storyboard board)? onChange;

  /// Pack sheets as soon as they are full. Off on Android, where the native
  /// loop skips frames whose tile files exist and must find them again
  /// after a cancel.
  final bool packEarly;

  Storyboard _board;
  Storyboard get board => _board;

  /// Where the user is looking: frames near it are made first.
  Duration? focus;

  /// How many frames around [focus] jump the queue.
  static const focusRadius = 3;

  final _orders = <int, List<int>>{};
  final _cursor = <int, int>{};
  Future<void> _packing = Future.value();
  final _packed = <(int, int)>{};

  /// The next frame of [level] to make, or null when every frame is done.
  int? next(int level) {
    final l = _board.levels[level];
    final f = focus;
    if (f != null) {
      final want = l.spec.indexAt(f);
      for (var d = 0; d <= focusRadius; d++) {
        for (final i in [want + d, want - d]) {
          if (i >= 0 && i < l.spec.count && !l.done(i)) return i;
        }
      }
    }
    final order = _orders[level] ??= coarseToFine(l.spec.count);
    var c = _cursor[level] ?? 0;
    while (c < order.length && l.done(order[c])) {
      c++;
    }
    _cursor[level] = c;
    return c < order.length ? order[c] : null;
  }

  /// The tile of [frame] in [level] was written.
  void tileWritten(int level, int frame) {
    final l = _board.levels[level];
    if (l.tiles.contains(frame)) return;
    _update(l.copyWith(tiles: {...l.tiles, frame}));
    _maybePack(level, frame);
  }

  /// [frame] couldn't be made.
  void tileFailed(int level, int frame) {
    final l = _board.levels[level];
    if (l.failed.contains(frame)) return;
    _update(l.copyWith(failed: {...l.failed, frame}));
    _maybePack(level, frame);
  }

  void _maybePack(int level, int frame) {
    if (!packEarly) return;
    final l = _board.levels[level];
    final sheet = l.spec.sheetOf(frame);
    if (l.spec.framesOf(sheet).every(l.done)) _queuePack(level, sheet);
  }

  /// Every frame of [level] was tried: packs what is left and marks it
  /// complete when few enough failed. Frames neither written nor failed
  /// count as failed.
  Future<void> finishLevel(int level) async {
    var l = _board.levels[level];
    final missing = {
      for (var i = 0; i < l.spec.count; i++)
        if (!l.done(i)) i,
    };
    if (missing.isNotEmpty) {
      l = l.copyWith(failed: {...l.failed, ...missing});
      _update(l);
    }
    for (var s = 0; s < l.spec.sheetCount; s++) {
      if (!l.sheets.contains(s)) _queuePack(level, s);
    }
    await flush();
    l = _board.levels[level];
    final ok =
        l.ready > 0 &&
        Storyboard.acceptable(l.spec.count, l.failed) &&
        l.tiles.isEmpty;
    _update(l.copyWith(complete: ok));
    await _writeSpec();
  }

  /// Waits for sheets being packed.
  Future<void> flush() => _packing;

  void _queuePack(int level, int sheet) {
    if (!_packed.add((level, sheet))) return;
    _packing = _packing.then((_) => _pack(level, sheet));
  }

  Future<void> _pack(int level, int sheet) async {
    final l = _board.levels[level];
    // One entry per cell; null leaves it empty.
    final tiles = l.spec
        .framesOf(sheet)
        .map((i) => l.tiles.contains(i) ? _board.tilePath(level, i) : null)
        .toList();
    if (tiles.every((t) => t == null)) {
      // Nothing to show in it: every frame failed.
      _update(l.copyWith(sheets: {...l.sheets, sheet}));
      return;
    }
    final out = _board.sheetPath(level, sheet);
    final ok = await packSheet(
      tiles: tiles,
      cols: l.spec.cols,
      rows: l.spec.rows,
      out: out,
    );
    final now = _board.levels[level];
    if (!ok) {
      // Keep the tiles: they still show; the next render tries again.
      _packed.remove((level, sheet));
      return;
    }
    final frames = l.spec.framesOf(sheet).toSet();
    _update(
      now.copyWith(
        sheets: {...now.sheets, sheet},
        tiles: now.tiles.difference(frames),
      ),
    );
    await _writeSpec();
    for (final t in tiles) {
      if (t == null) continue;
      try {
        await File(t).delete();
      } on FileSystemException {
        // Already gone.
      }
    }
  }

  Future<void> _writeSpec() async {
    try {
      _board.writeSpec();
    } on FileSystemException {
      // The folder was trimmed away: the next render starts over.
    }
  }

  void _update(LevelFrames level) {
    _board = _board.withLevel(level);
    onChange?.call(_board);
  }
}

/// Packs JPEG [tiles] (null: an empty cell) into one [cols]×[rows] sheet at
/// [out], in a background isolate. False when no tile could be read.
Future<bool> packSheet({
  required List<String?> tiles,
  required int cols,
  required int rows,
  required String out,
  int quality = 75,
}) => Isolate.run(() => packSheetSync(tiles, cols, rows, out, quality));

/// [packSheet]'s work, for the isolate (and tests).
bool packSheetSync(
  List<String?> tiles,
  int cols,
  int rows,
  String out,
  int quality,
) {
  final decoded = tiles.map((t) => t == null ? null : _decode(t)).toList();
  final first = decoded.whereType<img.Image>().firstOrNull;
  if (first == null) return false;
  final w = first.width;
  final h = first.height;
  final sheet = img.Image(width: cols * w, height: rows * h);
  for (var i = 0; i < decoded.length; i++) {
    var tile = decoded[i];
    if (tile == null) continue;
    if (tile.width != w || tile.height != h) {
      tile = img.copyResize(tile, width: w, height: h);
    }
    img.compositeImage(
      sheet,
      tile,
      dstX: (i % cols) * w,
      dstY: (i ~/ cols) * h,
    );
  }
  File('$out.part')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(img.encodeJpg(sheet, quality: quality))
    ..renameSync(out);
  return true;
}

img.Image? _decode(String path) {
  try {
    return img.decodeJpg(File(path).readAsBytesSync());
  } on Object {
    return null;
  }
}

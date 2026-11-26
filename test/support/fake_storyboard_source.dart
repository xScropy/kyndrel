import 'dart:io';

import 'package:kyndrel/core/player/storyboard.dart';

import 'tiny_jpeg.dart';

/// Writes tiny frame tiles instead of decoding video, level by level.
class FakeStoryboardSource implements StoryboardSource {
  final rendered = <Storyboard>[];
  final focused = <Duration>[];
  int cancels = 0;

  /// Frames of the fine level (1) to write; all of them when null.
  Set<int>? only;

  @override
  Future<bool> render(
    Storyboard board, {
    void Function(Storyboard board)? onChange,
  }) async {
    rendered.add(board);
    final bytes = tinyJpeg();
    var b = board;
    for (final level in board.levels) {
      final n = level.spec.index;
      Directory(b.tilesDirectory(n)).createSync(recursive: true);
      final tiles = <int>{};
      final failed = <int>{};
      for (var i = 0; i < level.spec.count; i++) {
        if (n == 0 || only == null || only!.contains(i)) {
          File(b.tilePath(n, i)).writeAsBytesSync(bytes);
          tiles.add(i);
        } else {
          failed.add(i);
        }
      }
      b = b.withLevel(
        LevelFrames(level.spec, tiles: tiles, failed: failed, complete: true),
      );
      onChange?.call(b);
    }
    b.writeSpec();
    return true;
  }

  @override
  void focus(Duration at) => focused.add(at);

  @override
  Future<void> cancel() async => cancels++;
}

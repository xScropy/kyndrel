import 'dart:io';

import 'package:kyndrel/core/player/storyboard.dart';

/// Writes empty frame files instead of decoding video.
class FakeStoryboardSource implements StoryboardSource {
  final rendered = <Storyboard>[];
  int cancels = 0;

  /// Frames to write; all of them when null.
  Set<int>? only;

  @override
  Future<bool> render(Storyboard board) async {
    rendered.add(board);
    Directory(board.directory).createSync(recursive: true);
    for (var i = 0; i < board.count; i++) {
      if (only == null || only!.contains(i)) {
        File(board.pathOf(i)).writeAsBytesSync(const [0xFF, 0xD8]);
      }
    }
    board.writeIndex();
    return true;
  }

  @override
  Future<void> cancel() async => cancels++;
}

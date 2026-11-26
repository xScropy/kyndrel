import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/core/player/preview_thumbnailer.dart';
import 'package:kyndrel/core/player/storyboard.dart';

/// The picture shown while scrubbing (task 7.2): the storyboard frame
/// nearest the position at once, then the exact frame once the finger or
/// cursor rests. Without a storyboard yet, the nearest cached step as
/// before (3.7).
class ScrubPreview {
  new(this._ref, this._onFrame);

  /// How long the position must rest before the exact frame is made.
  static const rest = Duration(milliseconds: 150);

  /// Before the storyboard exists: a short wait so fast moves don't queue
  /// renders.
  static const debounce = Duration(milliseconds: 60);

  final WidgetRef _ref;
  final void Function(FrameRef frame) _onFrame;
  Timer? _timer;
  int _id = 0;

  void request(String source, Duration at, Duration duration) {
    _timer?.cancel();
    final id = ++_id;
    final board = _ref.read(storyboardProvider);
    FrameRef? quick;
    if (board != null && board.source == source) {
      quick = board.nearest(at);
      // Frames near the finger are made next (task 8.2).
      if (!board.complete) _ref.read(storyboardProvider.notifier).focus(at);
    }
    if (quick != null) _onFrame(quick);
    _timer = Timer(quick == null ? debounce : rest, () async {
      final path = await _ref
          .read(previewSourceProvider)
          .frameAt(source, at, duration, exact: quick != null);
      if (id == _id && path != null) _onFrame(FrameRef(path));
    });
  }

  /// Ignores answers still on their way (the preview was closed).
  void cancel() {
    _timer?.cancel();
    _id++;
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/player/storyboard.dart';
import 'package:kyndrel/core/storage/app_directories.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/ui/frame_view.dart';
import 'package:material_ui/material_ui.dart';

/// A library thumbnail that flips through the video's scenes, like
/// YouTube's home page (task 8.6): move the mouse across it, or slide a
/// finger sideways on it. Uses the coarse storyboard made in advance
/// (8.4), so it decodes no video and costs one small image.
class SceneThumbnail extends ConsumerStatefulWidget {
  const new({
    required this.item,
    required this.child,
    this.touch = true,
    super.key,
  });

  final LibraryItem item;
  final Widget child;

  /// Sideways finger slides scrub (off inside sideways-scrolling rows).
  final bool touch;

  @override
  ConsumerState<SceneThumbnail> createState() => _SceneThumbnailState();
}

class _SceneThumbnailState extends ConsumerState<SceneThumbnail> {
  Storyboard? _board;
  bool _looked = false;
  FrameRef? _frame;
  double _fraction = 0;

  /// The coarse storyboard if it is ready; read once per thumbnail.
  Storyboard? _boardFor() {
    if (_looked) return _board;
    _looked = true;
    final ms = widget.item.durationMs;
    if (ms == null || ms <= 0) return null;
    final b = Storyboard.read(
      ref.read(appCacheDirProvider),
      widget.item.uri,
      Duration(milliseconds: ms),
    );
    return _board = b.levels.first.complete ? b : null;
  }

  void _scrub(double x, double width) {
    final b = _boardFor();
    if (b == null || width <= 0) return;
    final f = (x / width).clamp(0.0, 1.0);
    final level = b.levels.first.spec;
    final frame = b.frame(0, (f * (level.count - 1)).round());
    if (frame == null) return;
    setState(() {
      _fraction = f;
      _frame = frame;
    });
  }

  void _stop() {
    if (_frame != null) setState(() => _frame = null);
  }

  @override
  void didUpdateWidget(SceneThumbnail old) {
    super.didUpdateWidget(old);
    if (old.item.uri != widget.item.uri ||
        old.item.durationMs != widget.item.durationMs) {
      _looked = false;
      _board = null;
      _frame = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final frame = _frame;
        Widget child = Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (frame != null) ...[
              ClipRRect(
                key: const Key('scene-thumbnail-frame'),
                borderRadius: BorderRadius.circular(KyndrelTokens.tileRadius),
                child: FrameView(frame: frame),
              ),
              Align(
                alignment: AlignmentDirectional.bottomStart,
                child: FractionallySizedBox(
                  widthFactor: _fraction,
                  child: const SizedBox(
                    height: 3,
                    child: ColoredBox(color: KyndrelColors.accent),
                  ),
                ),
              ),
            ],
          ],
        );
        if (widget.touch) {
          child = GestureDetector(
            onHorizontalDragUpdate: (d) => _scrub(d.localPosition.dx, width),
            onHorizontalDragEnd: (_) => _stop(),
            onHorizontalDragCancel: _stop,
            child: child,
          );
        }
        return MouseRegion(
          onHover: (e) => _scrub(e.localPosition.dx, width),
          onExit: (_) => _stop(),
          child: child,
        );
      },
    );
  }
}

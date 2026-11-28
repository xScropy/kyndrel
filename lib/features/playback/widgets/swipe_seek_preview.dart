import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/scrub_preview.dart';
import 'package:kyndrel/core/player/storyboard.dart';
import 'package:kyndrel/core/ui/frame_view.dart';
import 'package:kyndrel/core/utils/time_format.dart';
import 'package:kyndrel/features/playback/widgets/video_gesture_layer.dart';
import 'package:material_ui/material_ui.dart';

/// The scene under your finger while swiping sideways on the video
/// (task 6.4): a large frame with the time and chapter, in the middle of
/// the screen.
class SwipeSeekPreview extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SwipeSeekPreview> createState() => _SwipeSeekPreviewState();
}

class _SwipeSeekPreviewState extends ConsumerState<SwipeSeekPreview> {
  Duration? _at;
  FrameRef? _frame;
  late final _scrub = ScrubPreview(ref, (frame) {
    if (mounted && _at != null && frame != _frame) {
      setState(() => _frame = frame);
    }
  });

  @override
  void initState() {
    super.initState();
    VideoGestureLayer.seekPreview.addListener(_onTarget);
  }

  @override
  void dispose() {
    VideoGestureLayer.seekPreview.removeListener(_onTarget);
    _scrub.cancel();
    super.dispose();
  }

  void _onTarget() {
    final at = VideoGestureLayer.seekPreview.value;
    setState(() {
      _at = at;
      if (at == null) _frame = null;
    });
    final state = ref.read(playerServiceProvider).state;
    final source = state.source;
    if (at == null || source == null) {
      _scrub.cancel();
      return;
    }
    // Storyboard frame at once, the exact one when the finger rests (7.2).
    _scrub.request(source, at, state.duration);
  }

  @override
  Widget build(BuildContext context) {
    final at = _at;
    if (at == null) return const SizedBox.shrink();
    final chapters =
        ref.watch(trackStateProvider.select((t) => t.value?.chapters)) ??
        const [];
    String? chapter;
    for (final c in chapters) {
      if (c.start <= at) chapter = c.title;
    }
    final width = (MediaQuery.sizeOf(context).width * 0.45).clamp(220.0, 420.0);
    final frame = _frame;
    return IgnorePointer(
      child: Container(
        key: const Key('swipe-seek-preview'),
        width: width,
        decoration: BoxDecoration(
          color: KyndrelColors.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KyndrelColors.panelBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: frame == null
                  ? const ColoredBox(color: KyndrelColors.background)
                  : FrameView(key: const Key('swipe-seek-frame'), frame: frame),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Column(
                children: [
                  Text(
                    formatDuration(at),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (chapter != null)
                    Text(
                      chapter,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: KyndrelColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

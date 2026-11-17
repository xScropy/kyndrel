import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/utils/time_format.dart';
import 'package:material_ui/material_ui.dart';

/// Seek bar with elapsed and total/remaining labels (task 1.4).
class SeekBarRow extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final duration = ref.watch(durationProvider).value ?? Duration.zero;
    final remaining = ref.watch(
      settingsProvider.select((s) => s.showRemainingTime),
    );
    final right = duration <= Duration.zero
        ? 'LIVE'
        : remaining
        ? formatDuration(-(duration - position))
        : formatDuration(duration);

    const labelStyle = TextStyle(
      fontSize: 13,
      fontFeatures: [FontFeature.tabularFigures()],
      color: KyndrelColors.textPrimary,
    );
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            formatDuration(position),
            key: const Key('seek-elapsed'),
            style: labelStyle,
          ),
        ),
        const Expanded(child: SeekBar()),
        SizedBox(
          width: 64,
          child: Tooltip(
            message: remaining ? 'Show total time' : 'Show remaining time',
            child: InkWell(
              key: const Key('seek-total'),
              borderRadius: BorderRadius.circular(6),
              onTap: () => ref
                  .read(settingsProvider.notifier)
                  .update((s) => s.copyWith(showRemainingTime: !remaining)),
              child: Text(right, textAlign: TextAlign.right, style: labelStyle),
            ),
          ),
        ),
      ],
    );
  }
}

/// The bar itself: buffered segment, orange progress with a round thumb,
/// hover tooltip, click and drag to seek.
class SeekBar extends ConsumerStatefulWidget {
  const new({super.key});

  /// While dragging, at most one seek per this interval; the final position
  /// is always sent on release.
  static const dragSeekInterval = Duration(milliseconds: 120);

  @override
  ConsumerState<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<SeekBar> {
  double? _hoverX;
  double? _dragFraction;
  Timer? _throttle;
  Duration? _pendingSeek;

  @override
  void dispose() {
    _throttle?.cancel();
    super.dispose();
  }

  void _seekThrottled(Duration target) {
    _pendingSeek = target;
    if (_throttle?.isActive ?? false) return;
    unawaited(ref.read(playerServiceProvider).seek(target));
    _pendingSeek = null;
    _throttle = Timer(SeekBar.dragSeekInterval, () {
      final pending = _pendingSeek;
      if (pending != null && _dragFraction != null) _seekThrottled(pending);
    });
  }

  Duration _at(double fraction, Duration duration) =>
      duration * fraction.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playbackStateProvider).value;
    final duration = state?.duration ?? Duration.zero;
    final position = state?.position ?? Duration.zero;
    final buffered = position + (state?.buffered ?? Duration.zero);
    final enabled = duration > Duration.zero;

    double fractionOf(Duration d) => enabled
        ? (d.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0)
        : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double fractionAt(double x) => (x / width).clamp(0.0, 1.0);
        final progress = _dragFraction ?? fractionOf(position);
        final hoverX = _hoverX;

        return MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onHover: (e) => setState(() => _hoverX = e.localPosition.dx),
          onExit: (_) => setState(() => _hoverX = null),
          child: GestureDetector(
            key: const Key('seek-bar'),
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onTapUp: enabled
                ? (d) => unawaited(
                    ref
                        .read(playerServiceProvider)
                        .seek(_at(fractionAt(d.localPosition.dx), duration)),
                  )
                : null,
            onHorizontalDragStart: enabled
                ? (d) => setState(
                    () => _dragFraction = fractionAt(d.localPosition.dx),
                  )
                : null,
            onHorizontalDragUpdate: enabled
                ? (d) {
                    final f = fractionAt(d.localPosition.dx);
                    setState(() {
                      _dragFraction = f;
                      _hoverX = d.localPosition.dx;
                    });
                    _seekThrottled(_at(f, duration));
                  }
                : null,
            onHorizontalDragEnd: enabled
                ? (_) {
                    final f = _dragFraction;
                    _throttle?.cancel();
                    _pendingSeek = null;
                    if (f != null) {
                      unawaited(
                        ref.read(playerServiceProvider).seek(_at(f, duration)),
                      );
                    }
                    setState(() => _dragFraction = null);
                  }
                : null,
            child: SizedBox(
              height: 32,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: SeekBarPainter(
                        progress: progress,
                        buffered: fractionOf(buffered),
                        hovering: hoverX != null || _dragFraction != null,
                      ),
                    ),
                  ),
                  if (hoverX != null && enabled)
                    Positioned(
                      left: (hoverX - 32).clamp(0, width - 64),
                      bottom: 30,
                      child: _TimeBubble(
                        text: formatDuration(_at(fractionAt(hoverX), duration)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimeBubble extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('seek-hover-time'),
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: KyndrelColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KyndrelColors.panelBorder),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class SeekBarPainter extends CustomPainter {
  new({required this.progress, required this.buffered, required this.hovering});

  final double progress;
  final double buffered;
  final bool hovering;

  @override
  void paint(Canvas canvas, Size size) {
    final track = hovering ? 6.0 : 4.0;
    final y = size.height / 2;
    final r = Radius.circular(track / 2);
    RRect bar(double to) =>
        RRect.fromLTRBR(0, y - track / 2, to, y + track / 2, r);

    canvas
      ..drawRRect(bar(size.width), Paint()..color = KyndrelColors.track)
      ..drawRRect(
        bar(size.width * buffered),
        Paint()..color = KyndrelColors.trackBuffered,
      )
      ..drawRRect(
        bar(size.width * progress),
        Paint()..color = KyndrelColors.accent,
      )
      ..drawCircle(
        Offset(size.width * progress, y),
        hovering ? 8 : 6,
        Paint()..color = KyndrelColors.accent,
      );
  }

  @override
  bool shouldRepaint(SeekBarPainter old) =>
      old.progress != progress ||
      old.buffered != buffered ||
      old.hovering != hovering;
}

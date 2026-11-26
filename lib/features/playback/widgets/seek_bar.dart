import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/platform/platform_capabilities.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/scrub_preview.dart';
import 'package:kyndrel/core/player/storyboard.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/core/ui/frame_view.dart';
import 'package:kyndrel/core/utils/time_format.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Seek bar with elapsed and total/remaining labels (task 1.4).
class SeekBarRow extends ConsumerWidget {
  const new({super.key});

  /// Fixed height (the bar's hit area), so the row is a relayout boundary.
  static const double height = 32;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final duration = ref.watch(durationProvider).value ?? Duration.zero;
    final remaining = ref.watch(
      settingsProvider.select((s) => s.showRemainingTime),
    );
    final right = duration <= Duration.zero
        ? context.l10n.live
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
            message: remaining
                ? context.l10n.showTotalTime
                : context.l10n.showRemainingTime,
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
  PointerDeviceKind? _dragKind;
  FrameRef? _preview;
  late final _scrub = ScrubPreview(ref, (frame) {
    if (mounted && _hoverX != null && frame != _preview) {
      setState(() => _preview = frame);
    }
  });

  @override
  void dispose() {
    _throttle?.cancel();
    _scrub.cancel();
    super.dispose();
  }

  /// The scene at the hovered or dragged time: the storyboard frame at
  /// once, the exact one when the pointer rests (tasks 3.7, 7.2).
  void _requestPreview(Duration at, Duration duration) {
    final source = ref.read(playerServiceProvider).state.source;
    if (source == null) return;
    _scrub.request(source, at, duration);
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

  static Duration _clamp(Duration d, Duration max) =>
      d < Duration.zero ? Duration.zero : (d > max ? max : d);

  Duration _at(double fraction, Duration duration) =>
      duration * fraction.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(platformCapabilitiesProvider).isMobile;
    final state = ref.watch(playbackStateProvider).value;
    final duration = state?.duration ?? Duration.zero;
    final position = state?.position ?? Duration.zero;
    final buffered = position + (state?.buffered ?? Duration.zero);
    final enabled = duration > Duration.zero;
    final skip = Duration(
      seconds: ref.watch(settingsProvider.select((s) => s.skipSeconds)),
    );
    final chapters =
        ref.watch(trackStateProvider.select((t) => t.value?.chapters)) ??
        const [];
    final (loopA, loopB) = ref.watch(
      trackStateProvider.select((t) => (t.value?.loopA, t.value?.loopB)),
    );

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
          onHover: (e) {
            setState(() => _hoverX = e.localPosition.dx);
            if (enabled) {
              _requestPreview(
                _at(fractionAt(e.localPosition.dx), duration),
                duration,
              );
            }
          },
          onExit: (_) => setState(() {
            _hoverX = null;
            _preview = null;
            _scrub.cancel();
          }),
          // A screen-reader slider: arrow/volume-key gestures seek by the
          // skip interval (task 5.3).
          child: Semantics(
            slider: true,
            label: context.l10n.seekLabel,
            value: context.l10n.seekValue(
              formatDuration(position),
              formatDuration(duration),
            ),
            increasedValue: enabled
                ? context.l10n.seekValue(
                    formatDuration(_clamp(position + skip, duration)),
                    formatDuration(duration),
                  )
                : null,
            decreasedValue: enabled
                ? context.l10n.seekValue(
                    formatDuration(_clamp(position - skip, duration)),
                    formatDuration(duration),
                  )
                : null,
            onIncrease: enabled
                ? () => unawaited(ref.read(playerServiceProvider).seekBy(skip))
                : null,
            onDecrease: enabled
                ? () => unawaited(ref.read(playerServiceProvider).seekBy(-skip))
                : null,
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
                  ? (d) {
                      _dragKind = d.kind;
                      setState(
                        () => _dragFraction = fractionAt(d.localPosition.dx),
                      );
                    }
                  : null,
              onHorizontalDragUpdate: enabled
                  ? (d) {
                      final f = fractionAt(d.localPosition.dx);
                      setState(() {
                        _dragFraction = f;
                        _hoverX = d.localPosition.dx;
                      });
                      _seekThrottled(_at(f, duration));
                      _requestPreview(_at(f, duration), duration);
                    }
                  : null,
              onHorizontalDragEnd: enabled
                  ? (_) {
                      final f = _dragFraction;
                      _throttle?.cancel();
                      _pendingSeek = null;
                      if (f != null) {
                        unawaited(
                          ref
                              .read(playerServiceProvider)
                              .seek(_at(f, duration)),
                        );
                      }
                      setState(() {
                        _dragFraction = null;
                        // A finger has no hover: the preview goes with it.
                        if (_dragKind == PointerDeviceKind.touch ||
                            _dragKind == PointerDeviceKind.stylus) {
                          _hoverX = null;
                          _preview = null;
                          _scrub.cancel();
                        }
                      });
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
                          marks: [
                            for (final c in chapters)
                              if (c.start > Duration.zero) fractionOf(c.start),
                          ],
                          loopA: loopA == null ? null : fractionOf(loopA),
                          loopB: loopB == null ? null : fractionOf(loopB),
                        ),
                      ),
                    ),
                    if (hoverX != null && enabled)
                      Builder(
                        builder: (context) {
                          final at = _at(fractionAt(hoverX), duration);
                          String? chapter;
                          for (final c in chapters) {
                            if (c.start <= at) chapter = c.title;
                          }
                          final preview = _preview;
                          // Phones: a big frame to find the scene (6.4).
                          final frameWidth = phone
                              ? (width * 0.4).clamp(200.0, 360.0)
                              : 176.0;
                          final bubble = preview == null
                              ? 140.0
                              : frameWidth + 4;
                          return Positioned(
                            left: (hoverX - bubble / 2).clamp(
                              0,
                              width - bubble,
                            ),
                            bottom: 30,
                            width: bubble,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (preview != null)
                                  Container(
                                    key: const Key('seek-preview'),
                                    margin: const EdgeInsets.only(bottom: 4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: KyndrelColors.panelBorder,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: FrameView(
                                      frame: preview,
                                      width: frameWidth,
                                    ),
                                  ),
                                _TimeBubble(
                                  text: formatDuration(at),
                                  chapter: chapter,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimeBubble extends StatelessWidget {
  const new({required this.text, this.chapter});

  final String text;
  final String? chapter;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('seek-hover-time'),
      constraints: const BoxConstraints(minWidth: 64, maxWidth: 140),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: KyndrelColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KyndrelColors.panelBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chapter != null)
            Text(
              chapter!,
              key: const Key('seek-hover-chapter'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: KyndrelColors.textSecondary,
              ),
            ),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class SeekBarPainter extends CustomPainter {
  new({
    required this.progress,
    required this.buffered,
    required this.hovering,
    this.marks = const [],
    this.loopA,
    this.loopB,
  });

  final double progress;
  final double buffered;
  final bool hovering;

  /// Chapter starts as 0–1 fractions (task 3.6).
  final List<double> marks;

  /// A-B loop points as fractions (task 3.9).
  final double? loopA;
  final double? loopB;

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
      );
    // Chapter marks: small gaps in the bar.
    final gap = Paint()..color = KyndrelColors.background;
    for (final m in marks) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(size.width * m, y),
          width: 2,
          height: track + 1,
        ),
        gap,
      );
    }
    // A-B loop range.
    final a = loopA;
    if (a != null) {
      final loopPaint = Paint()..color = KyndrelColors.textPrimary;
      final b = loopB;
      if (b != null) {
        canvas.drawRect(
          Rect.fromLTRB(
            size.width * a,
            y - track,
            size.width * b,
            y - track + 2,
          ),
          loopPaint,
        );
      }
      for (final f in [a, ?b]) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(size.width * f, y),
            width: 2,
            height: 14,
          ),
          loopPaint,
        );
      }
    }
    canvas.drawCircle(
      Offset(size.width * progress, y),
      hovering ? 8 : 6,
      Paint()..color = KyndrelColors.accent,
    );
  }

  @override
  bool shouldRepaint(SeekBarPainter old) =>
      old.progress != progress ||
      old.buffered != buffered ||
      old.hovering != hovering ||
      !listEquals(old.marks, marks) ||
      old.loopA != loopA ||
      old.loopB != loopB;
}

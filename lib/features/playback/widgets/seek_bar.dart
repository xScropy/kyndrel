import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/platform/platform_capabilities.dart';
import 'package:kyndrel/core/player/media_track.dart';
import 'package:kyndrel/core/player/player_providers.dart';
import 'package:kyndrel/core/player/scrub_preview.dart';
import 'package:kyndrel/core/player/storyboard.dart';
import 'package:kyndrel/core/storage/bookmark_repository.dart';
import 'package:kyndrel/core/storage/database.dart';
import 'package:kyndrel/core/storage/replay_repository.dart';
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

  /// Builds of the bar (tests check pointer moves don't rebuild it,
  /// task 8.3).
  @visibleForTesting
  static int debugBuilds = 0;

  @override
  ConsumerState<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<SeekBar> {
  // What changes on every pointer move lives in notifiers, so a move
  // repaints the bar and the bubble only (task 8.3).
  final _hoverX = ValueNotifier<double?>(null);
  final _dragFraction = ValueNotifier<double?>(null);
  final _preview = ValueNotifier<FrameRef?>(null);
  late final _moves = Listenable.merge([_hoverX, _dragFraction]);
  late final _bubble = Listenable.merge([_hoverX, _preview]);

  Timer? _throttle;
  Duration? _pendingSeek;
  PointerDeviceKind? _dragKind;
  int? _chapter;
  late final _scrub = ScrubPreview(ref, (frame) {
    if (mounted && _hoverX.value != null) _preview.value = frame;
  });

  @override
  void dispose() {
    _throttle?.cancel();
    _scrub.cancel();
    _hoverX.dispose();
    _dragFraction.dispose();
    _preview.dispose();
    super.dispose();
  }

  /// The scene at the hovered or dragged time: the storyboard frame at
  /// once, the exact one when the pointer rests (tasks 3.7, 7.2).
  void _requestPreview(Duration at, Duration duration) {
    final source = ref.read(playerServiceProvider).state.source;
    if (source == null) return;
    _scrub.request(source, at, duration);
    // Decode the sheets around the finger before it gets there (8.3).
    final board = ref.read(storyboardProvider);
    if (board != null && board.source == source) {
      prefetchSheets(ref.read(frameImageCacheProvider), board, at);
    }
  }

  void _hide() {
    _hoverX.value = null;
    _preview.value = null;
    _chapter = null;
    _scrub.cancel();
  }

  /// A light tick when the finger crosses into another chapter (phones).
  void _chapterTick(List<Chapter> chapters, Duration at) {
    var index = -1;
    for (var i = 0; i < chapters.length; i++) {
      if (chapters[i].start <= at) index = i;
    }
    if (_chapter != null && index != _chapter && index >= 0) {
      unawaited(HapticFeedback.selectionClick());
    }
    _chapter = index;
  }

  void _seekThrottled(Duration target) {
    _pendingSeek = target;
    if (_throttle?.isActive ?? false) return;
    unawaited(ref.read(playerServiceProvider).seek(target));
    _pendingSeek = null;
    _throttle = Timer(SeekBar.dragSeekInterval, () {
      final pending = _pendingSeek;
      if (pending != null && _dragFraction.value != null) {
        _seekThrottled(pending);
      }
    });
  }

  static Duration _clamp(Duration d, Duration max) =>
      d < Duration.zero ? Duration.zero : (d > max ? max : d);

  Duration _at(double fraction, Duration duration) =>
      duration * fraction.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    SeekBar.debugBuilds++;
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
    final source = state?.source;
    final bookmarks = source == null
        ? const <Bookmark>[]
        : ref.watch(bookmarksProvider(source)).value ?? const <Bookmark>[];
    final heat =
        source == null ||
            !ref.watch(settingsProvider.select((s) => s.showHeatmap))
        ? const <double>[]
        : ref.watch(heatmapProvider(source)).value ?? const <double>[];

    double fractionOf(Duration d) => enabled
        ? (d.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0)
        : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double fractionAt(double x) => (x / width).clamp(0.0, 1.0);

        return MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onHover: (e) {
            _hoverX.value = e.localPosition.dx;
            if (enabled) {
              _requestPreview(
                _at(fractionAt(e.localPosition.dx), duration),
                duration,
              );
            }
          },
          onExit: (_) => _hide(),
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
                      _dragFraction.value = fractionAt(d.localPosition.dx);
                    }
                  : null,
              onHorizontalDragUpdate: enabled
                  ? (d) {
                      final f = fractionAt(d.localPosition.dx);
                      final at = _at(f, duration);
                      _dragFraction.value = f;
                      _hoverX.value = d.localPosition.dx;
                      if (phone) _chapterTick(chapters, at);
                      _seekThrottled(at);
                      _requestPreview(at, duration);
                    }
                  : null,
              onHorizontalDragEnd: enabled
                  ? (_) {
                      final f = _dragFraction.value;
                      _throttle?.cancel();
                      _pendingSeek = null;
                      if (f != null) {
                        unawaited(
                          ref
                              .read(playerServiceProvider)
                              .seek(_at(f, duration)),
                        );
                      }
                      _dragFraction.value = null;
                      // A finger has no hover: the preview goes with it.
                      if (_dragKind == PointerDeviceKind.touch ||
                          _dragKind == PointerDeviceKind.stylus) {
                        _hide();
                      }
                    }
                  : null,
              child: SizedBox(
                height: 32,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: ListenableBuilder(
                          listenable: _moves,
                          builder: (context, _) => CustomPaint(
                            painter: SeekBarPainter(
                              progress:
                                  _dragFraction.value ?? fractionOf(position),
                              buffered: fractionOf(buffered),
                              hovering:
                                  _hoverX.value != null ||
                                  _dragFraction.value != null,
                              marks: [
                                for (final c in chapters)
                                  if (c.start > Duration.zero)
                                    fractionOf(c.start),
                              ],
                              heat: heat,
                              bookmarks: [
                                for (final b in bookmarks)
                                  fractionOf(
                                    Duration(milliseconds: b.positionMs),
                                  ),
                              ],
                              loopA: loopA == null ? null : fractionOf(loopA),
                              loopB: loopB == null ? null : fractionOf(loopB),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (enabled)
                      ListenableBuilder(
                        listenable: _bubble,
                        builder: (context, _) {
                          final hoverX = _hoverX.value;
                          if (hoverX == null) return const SizedBox.shrink();
                          final at = _at(fractionAt(hoverX), duration);
                          String? chapter;
                          for (final c in chapters) {
                            if (c.start <= at) chapter = c.title;
                          }
                          final preview = _preview.value;
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
                            child: RepaintBoundary(
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
    this.bookmarks = const [],
    this.heat = const [],
    this.loopA,
    this.loopB,
  });

  /// "Most replayed": 0–1 heights along the bar (task 8.10), drawn while
  /// hovering.
  final List<double> heat;

  /// Bookmarks as 0–1 fractions (task 8.8): small orange ticks above.
  final List<double> bookmarks;

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

    // Most replayed: a soft curve above the bar while hovering.
    if (hovering && heat.length > 1) {
      final top = y - track / 2 - 2;
      const tall = 14.0;
      final path = Path()..moveTo(0, top);
      for (var i = 0; i < heat.length; i++) {
        final x = size.width * (i + 0.5) / heat.length;
        path.lineTo(x, top - tall * heat[i]);
      }
      path
        ..lineTo(size.width, top)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = KyndrelColors.accent.withValues(alpha: 0.35),
      );
    }
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
    // Bookmarks: orange ticks over the bar.
    final tick = Paint()..color = KyndrelColors.accent;
    for (final b in bookmarks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width * b, y - track / 2 - 4),
            width: 3,
            height: 7,
          ),
          const Radius.circular(1.5),
        ),
        tick,
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
      !listEquals(old.bookmarks, bookmarks) ||
      !listEquals(old.heat, heat) ||
      old.loopA != loopA ||
      old.loopB != loopB;
}

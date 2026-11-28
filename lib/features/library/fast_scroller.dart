import 'dart:async';

import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:material_ui/material_ui.dart';

/// A draggable thumb on the edge of a long list, with a bubble saying
/// where it is (the letter, month or size there), like MX Player and
/// Google Photos (task 8.6).
///
/// Dragging jumps the list straight to that point: lists use fixed row
/// heights, so the jump costs nothing however long the list is. The thumb
/// shows while scrolling or hovering and fades after [hideAfter].
class FastScroller extends StatefulWidget {
  const new({
    required this.controller,
    required this.itemCount,
    required this.labelAt,
    required this.child,
    super.key,
  });

  final ScrollController controller;
  final int itemCount;

  /// The bubble text for the item at an index.
  final String Function(int index) labelAt;
  final Widget child;

  /// Lists shorter than this many screens get no thumb.
  static const minScreens = 3.0;

  static const hideAfter = Duration(milliseconds: 1500);
  static const thumbHeight = 48.0;
  static const width = 28.0;

  @override
  State<FastScroller> createState() => _FastScrollerState();
}

class _FastScrollerState extends State<FastScroller> {
  final ValueNotifier<bool> _visible = ValueNotifier(false);
  final ValueNotifier<bool> _dragging = ValueNotifier(false);
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    _visible.dispose();
    _dragging.dispose();
    super.dispose();
  }

  void _show() {
    _visible.value = true;
    _hide?.cancel();
    if (!_dragging.value) {
      _hide = Timer(FastScroller.hideAfter, () {
        if (mounted && !_dragging.value) _visible.value = false;
      });
    }
  }

  /// One list attached (switching list ↔ grid briefly attaches two).
  bool get _attached => widget.controller.positions.length == 1;

  bool get _long {
    final c = widget.controller;
    if (!_attached) return false;
    final pos = c.position;
    return pos.hasContentDimensions &&
        pos.maxScrollExtent >
            pos.viewportDimension * (FastScroller.minScreens - 1);
  }

  double get _fraction {
    final c = widget.controller;
    if (!_attached || !c.position.hasContentDimensions) return 0;
    final max = c.position.maxScrollExtent;
    return max <= 0 ? 0 : (c.offset / max).clamp(0.0, 1.0);
  }

  void _dragTo(double dy, double height) {
    final track = height - FastScroller.thumbHeight;
    final f = ((dy - FastScroller.thumbHeight / 2) / track).clamp(0.0, 1.0);
    final c = widget.controller;
    if (_attached) c.jumpTo(c.position.maxScrollExtent * f);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollUpdateNotification && _long) _show();
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          return Stack(
            children: [
              widget.child,
              PositionedDirectional(
                top: 0,
                bottom: 0,
                end: 0,
                width: FastScroller.width,
                child: MouseRegion(
                  onEnter: (_) {
                    if (_long) _show();
                  },
                  child: GestureDetector(
                    key: const Key('fast-scroller'),
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragStart: (d) {
                      if (!_long) return;
                      _dragging.value = true;
                      _show();
                      _dragTo(d.localPosition.dy, height);
                    },
                    onVerticalDragUpdate: (d) {
                      if (_dragging.value) _dragTo(d.localPosition.dy, height);
                    },
                    onVerticalDragEnd: (_) {
                      _dragging.value = false;
                      _show();
                    },
                    child: ListenableBuilder(
                      listenable: Listenable.merge([
                        _visible,
                        _dragging,
                        widget.controller,
                      ]),
                      builder: (context, _) => _thumb(height),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _thumb(double height) {
    final show = _visible.value && _long;
    final top = (height - FastScroller.thumbHeight) * _fraction;
    final index = ((widget.itemCount - 1) * _fraction).round().clamp(
      0,
      widget.itemCount - 1,
    );
    return IgnorePointer(
      ignoring: !show,
      child: AnimatedOpacity(
        opacity: show ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: top,
              right: 4,
              child: Container(
                key: const Key('fast-scroller-thumb'),
                width: 6,
                height: FastScroller.thumbHeight,
                decoration: BoxDecoration(
                  color: _dragging.value
                      ? KyndrelColors.accent
                      : KyndrelColors.trackBuffered,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            if (_dragging.value && widget.itemCount > 0)
              Positioned(
                top: top + FastScroller.thumbHeight / 2 - 22,
                right: FastScroller.width + 4,
                child: Container(
                  key: const Key('fast-scroller-bubble'),
                  constraints: const BoxConstraints(minWidth: 44),
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: KyndrelColors.accent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    widget.labelAt(index),
                    style: const TextStyle(
                      color: KyndrelColors.onAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

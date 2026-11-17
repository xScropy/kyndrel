import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/core/platform/window_service.dart';
import 'package:material_ui/material_ui.dart';

/// Custom title bar for the frameless window (task 1.2).
///
/// The whole bar except the buttons drags the window; double-clicking it
/// maximizes or restores. [child] fills the draggable area (the top bar's
/// back button, title and badges in task 1.3).
class WindowTitleBar extends ConsumerWidget {
  const new({this.child, super.key});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(windowServiceProvider);
    return Container(
      height: KyndrelTokens.titleBarHeight,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [KyndrelColors.titleBarScrim, Color(0x00000000)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              key: const Key('title-bar-drag-area'),
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => unawaited(window.startDragging()),
              onDoubleTap: () => unawaited(window.toggleMaximize()),
              child: child ?? const SizedBox.expand(),
            ),
          ),
          const WindowButtons(),
        ],
      ),
    );
  }
}

/// Minimize, maximize/restore and close, in that order.
class WindowButtons extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(windowServiceProvider);
    final maximized =
        ref.watch(isMaximizedProvider).value ?? window.isMaximized;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WindowButton(
          key: const Key('window-minimize'),
          tooltip: 'Minimize',
          icon: Icons.remove,
          onPressed: window.minimize,
        ),
        _WindowButton(
          key: const Key('window-maximize'),
          tooltip: maximized ? 'Restore' : 'Maximize',
          icon: maximized ? Icons.filter_none : Icons.crop_square,
          iconSize: maximized ? 14 : 16,
          onPressed: window.toggleMaximize,
        ),
        _WindowButton(
          key: const Key('window-close'),
          tooltip: 'Close',
          icon: Icons.close,
          hoverColor: KyndrelColors.windowCloseHover,
          onPressed: window.close,
        ),
      ],
    );
  }
}

class _WindowButton extends StatefulWidget {
  const new({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.iconSize = 16,
    this.hoverColor = KyndrelColors.windowButtonHover,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final double iconSize;
  final Color hoverColor;
  final Future<void> Function() onPressed;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(widget.onPressed()),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 46,
            color: _hovered ? widget.hoverColor : const Color(0x00000000),
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: KyndrelColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

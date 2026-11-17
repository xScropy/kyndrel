import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/ui/controls_visibility.dart';
import 'package:material_ui/material_ui.dart';

/// Which edge of the anchor the popover lines up with.
enum PopoverAlign { left, center, right }

/// A translucent panel that opens above its anchor button (speed & sleep,
/// fit menu). Closes on outside click or Esc, and keeps the controls
/// visible while open (task 1.8).
class Popover extends ConsumerStatefulWidget {
  const new({
    required this.anchorBuilder,
    required this.contentBuilder,
    this.align = PopoverAlign.center,
    this.controller,
    super.key,
  });

  /// Builds the button; call `toggle` to open or close.
  final Widget Function(BuildContext context, VoidCallback toggle)
  anchorBuilder;

  /// Builds the panel content; call `close` after a choice if needed.
  final Widget Function(BuildContext context, VoidCallback close)
  contentBuilder;
  final PopoverAlign align;
  final OverlayPortalController? controller;

  @override
  ConsumerState<Popover> createState() => _PopoverState();
}

class _PopoverState extends ConsumerState<Popover> {
  final _link = LayerLink();
  late final OverlayPortalController _portal =
      widget.controller ?? OverlayPortalController();
  late final ControlsVisibility _visibility;

  @override
  void initState() {
    super.initState();
    _visibility = ref.read(controlsVisibilityProvider.notifier);
  }

  void _toggle() => _portal.isShowing ? _close() : _open();

  void _open() {
    _visibility.lock(this);
    setState(_portal.show);
  }

  void _close() {
    _visibility.unlock(this);
    if (mounted) setState(_portal.hide);
  }

  @override
  void dispose() {
    _visibility.unlock(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mirror the anchor in RTL, where the trigger sits on the other side.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final align = switch (widget.align) {
      PopoverAlign.left when rtl => PopoverAlign.right,
      PopoverAlign.right when rtl => PopoverAlign.left,
      final a => a,
    };
    final (target, follower) = switch (align) {
      PopoverAlign.left => (Alignment.topLeft, Alignment.bottomLeft),
      PopoverAlign.center => (Alignment.topCenter, Alignment.bottomCenter),
      PopoverAlign.right => (Alignment.topRight, Alignment.bottomRight),
    };
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const Key('popover-barrier'),
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            targetAnchor: target,
            followerAnchor: follower,
            offset: const Offset(0, -12),
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): _close,
              },
              child: Focus(
                autofocus: true,
                child: Container(
                  decoration: KyndrelTheme.panelDecoration(),
                  padding: const EdgeInsets.all(16),
                  child: Material(
                    type: MaterialType.transparency,
                    child: widget.contentBuilder(context, _close),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      child: CompositedTransformTarget(
        link: _link,
        child: widget.anchorBuilder(context, _toggle),
      ),
    );
  }
}

/// A selectable row in a popover list (speed values, sleep times, fit modes).
class PopoverOption extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.16)
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

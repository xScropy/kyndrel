import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/ui/harbor_icon.dart';
import 'package:material_ui/material_ui.dart';

/// Icon button used across the control bars, drawn like Harbor's (task
/// 9.2): a round 48 px target, the icon in white 85 % (white on hover), a
/// faint circle on hover and a brighter one while [active].
class ControlButton extends StatefulWidget {
  const new({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.active = false,
    this.size = 22,
    this.child,
    this.harbor,
    this.dot = false,
    super.key,
  });

  /// The Material icon, used when there is no [harbor] icon or [child].
  final IconData icon;

  /// Harbor's icon for this control.
  final HarborIconData? harbor;
  final String tooltip;
  final VoidCallback? onPressed;

  /// The feature is on (a menu open, a mode on): a brighter circle.
  final bool active;
  final double size;

  /// A small green dot at the top right (subtitles shown).
  final bool dot;

  /// Replaces the icon (e.g. a text label).
  final Widget? child;

  @override
  State<ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<ControlButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final touch = KyndrelTouch.of(context);
    final target = touch.target < 48 ? 48.0 : touch.target;
    final enabled = widget.onPressed != null;
    final color = !enabled
        ? KyndrelColors.textPrimary.withValues(alpha: 0.30)
        : _hover || widget.active
        ? KyndrelColors.textPrimary
        : KyndrelColors.controlIdle;
    final glyph =
        widget.child ??
        (widget.harbor != null
            ? HarborIcon(widget.harbor!, size: widget.size, color: color)
            : Icon(widget.icon, size: widget.size, color: color));
    final circle = widget.active
        ? (_hover ? KyndrelColors.trackBuffered : KyndrelColors.controlActive)
        : _hover && enabled
        ? KyndrelColors.controlHover
        : KyndrelColors.scrimClear;
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.tooltip,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: InkResponse(
            onTap: widget.onPressed,
            onHighlightChanged: (v) => setState(() => _down = v),
            radius: target / 2,
            hoverColor: KyndrelColors.scrimClear,
            splashColor: KyndrelColors.controlHover,
            highlightColor: KyndrelColors.scrimClear,
            focusColor: KyndrelColors.focus,
            child: AnimatedScale(
              scale: _down && enabled ? 0.9 : 1,
              duration: const Duration(milliseconds: 150),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                constraints: BoxConstraints(
                  minWidth: target,
                  minHeight: target,
                  maxHeight: target,
                ),
                decoration: BoxDecoration(
                  color: circle,
                  borderRadius: BorderRadius.circular(target / 2),
                ),
                padding: widget.child != null
                    ? const EdgeInsets.symmetric(horizontal: 10)
                    : EdgeInsets.zero,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    DefaultTextStyle.merge(
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      child: glyph,
                    ),
                    if (widget.dot)
                      PositionedDirectional(
                        top: target / 2 - widget.size / 2 - 3,
                        end: target / 2 - widget.size / 2 - 3,
                        child: Container(
                          key: const Key('control-dot'),
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: KyndrelColors.indicator,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

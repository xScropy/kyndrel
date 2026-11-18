import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Icon button used across the control bars: tooltip, hover highlight,
/// optional accent colour when active, and a disabled look for features
/// that aren't available yet.
class ControlButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.active = false,
    this.size = 22,
    this.child,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Draws the icon in the accent colour (e.g. subtitles on).
  final bool active;
  final double size;

  /// Replaces the icon (e.g. the speed button's `1.25×` text).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final touch = KyndrelTouch.of(context);
    final target = touch.target;
    final enabled = onPressed != null;
    final color = !enabled
        ? KyndrelColors.textPrimary.withValues(alpha: 0.35)
        : active
        ? KyndrelColors.accent
        : KyndrelColors.textPrimary;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: InkResponse(
          onTap: onPressed,
          radius: 22,
          hoverColor: KyndrelColors.windowButtonHover,
          focusColor: KyndrelColors.focus,
          child: ConstrainedBox(
            constraints: BoxConstraints.tightFor(height: target)
                .copyWith(minWidth: touch.touch ? target : 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  child: child ?? Icon(icon, size: size, color: color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:material_ui/material_ui.dart';

/// Builds the single dark theme Kyndrel ships with.
abstract final class KyndrelTheme {
  /// [touch] makes control buttons 48 dp touch targets (phones, 6.5).
  /// [black]: pure black backgrounds for OLED screens (task 8.8).
  static ThemeData dark({bool touch = false, bool black = false}) {
    final background = black ? KyndrelColors.black : KyndrelColors.background;
    final colors = ColorScheme.dark(
      primary: KyndrelColors.accent,
      onPrimary: KyndrelColors.onAccent,
      secondary: KyndrelColors.accent,
      onSecondary: KyndrelColors.onAccent,
      surface: black ? KyndrelColors.black : KyndrelColors.surface,
      error: KyndrelColors.error,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colors,
      fontFamily: KyndrelTokens.fontFamily,
      fontFamilyFallback: KyndrelTokens.fontFamilyFallback,
      scaffoldBackgroundColor: background,
      canvasColor: background,
    );

    return base.copyWith(
      extensions: [KyndrelTouch(touch: touch)],
      textTheme: base.textTheme.apply(
        bodyColor: KyndrelColors.textPrimary,
        displayColor: KyndrelColors.textPrimary,
      ),
      iconTheme: const IconThemeData(color: KyndrelColors.textPrimary),
      sliderTheme: const SliderThemeData(
        activeTrackColor: KyndrelColors.accent,
        inactiveTrackColor: KyndrelColors.track,
        thumbColor: KyndrelColors.accent,
        overlayColor: Color(0x33F26A1B),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: KyndrelColors.accent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: KyndrelColors.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: KyndrelColors.panelBorder),
        ),
        textStyle: const TextStyle(
          color: KyndrelColors.textPrimary,
          fontSize: 12,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: KyndrelColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KyndrelTokens.panelRadius),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: KyndrelColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KyndrelTokens.panelRadius),
        ),
      ),
    );
  }

  /// Muted small-caps label used for panel sections ("SLEEP TIMER").
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: KyndrelTokens.fontFamily,
    fontFamilyFallback: KyndrelTokens.fontFamilyFallback,
    color: KyndrelColors.sectionLabel,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: KyndrelTokens.sectionLabelLetterSpacing,
  );

  /// Decoration for translucent panels (popovers, subtitle panel).
  static BoxDecoration panelDecoration() => BoxDecoration(
    color: KyndrelColors.panel,
    borderRadius: BorderRadius.circular(KyndrelTokens.panelRadius),
    border: Border.all(color: KyndrelColors.panelBorder),
  );
}

/// Whether controls are sized for fingers (48 dp) rather than a mouse.
class KyndrelTouch extends ThemeExtension<KyndrelTouch> {
  const new({required this.touch});

  factory of(BuildContext context) =>
      Theme.of(context).extension<KyndrelTouch>() ??
      const KyndrelTouch(touch: false);

  final bool touch;

  /// Height of a control button.
  double get target => touch ? 48 : 40;

  @override
  KyndrelTouch copyWith({bool? touch}) =>
      KyndrelTouch(touch: touch ?? this.touch);

  @override
  KyndrelTouch lerp(KyndrelTouch? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

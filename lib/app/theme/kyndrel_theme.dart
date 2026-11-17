import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:material_ui/material_ui.dart';

/// Builds the single dark theme Kyndrel ships with.
abstract final class KyndrelTheme {
  static ThemeData dark() {
    const colors = ColorScheme.dark(
      primary: KyndrelColors.accent,
      onPrimary: KyndrelColors.textPrimary,
      secondary: KyndrelColors.accent,
      onSecondary: KyndrelColors.textPrimary,
      surface: KyndrelColors.surface,
      error: KyndrelColors.error,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colors,
      fontFamily: KyndrelTokens.fontFamily,
      fontFamilyFallback: KyndrelTokens.fontFamilyFallback,
      scaffoldBackgroundColor: KyndrelColors.background,
      canvasColor: KyndrelColors.background,
    );

    return base.copyWith(
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

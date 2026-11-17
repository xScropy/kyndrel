import 'package:material_ui/material_ui.dart';

/// Kyndrel colour tokens (PLAN.md §1, "Theme tokens").
///
/// Every colour in the UI comes from here. Do not hard-code colours in
/// widgets.
abstract final class KyndrelColors {
  /// Near-black app and video background.
  static const Color background = Color(0xFF0B0B0D);

  /// Base colour for raised surfaces (dialogs, menus).
  static const Color surface = Color(0xFF16161A);

  /// Translucent dark panel (popovers, subtitle panel, control bars).
  /// 90 % opaque: still shows the video, but text stays readable over
  /// bright frames.
  static const Color panel = Color(0xE61A1A1F);

  /// Hairline border on panels.
  static const Color panelBorder = Color(0x1FFFFFFF);

  /// Accent orange: progress, active rows, boosted volume, readouts.
  static const Color accent = Color(0xFFF26A1B);

  /// Accent used on hover/pressed states.
  static const Color accentHover = Color(0xFFFF8240);

  /// Primary text and icons.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Secondary text (year under the title, time labels).
  static const Color textSecondary = Color(0xB3FFFFFF);

  /// Muted grey small-caps section labels ("PLAYBACK SPEED").
  static const Color sectionLabel = Color(0xFF8A8A93);

  /// Seek/volume track behind the progress fill.
  static const Color track = Color(0x33FFFFFF);

  /// Buffered segment on the seek bar.
  static const Color trackBuffered = Color(0x66FFFFFF);

  /// Highlight behind the active row in lists and popovers.
  static const Color rowActive = Color(0x29F26A1B);

  /// Hover background of the minimize/maximize buttons.
  static const Color windowButtonHover = Color(0x1FFFFFFF);

  /// Hover background of the close button (Windows convention).
  static const Color windowCloseHover = Color(0xFFE81123);

  /// Top of the scrim behind the title bar, so it reads over bright video.
  static const Color titleBarScrim = Color(0xB3000000);

  /// Error text and icons.
  static const Color error = Color(0xFFFF5A5F);

  /// All tokens by name. Used by the golden test so a colour change is a
  /// deliberate, reviewed diff.
  static const Map<String, Color> all = {
    'background': background,
    'surface': surface,
    'panel': panel,
    'panelBorder': panelBorder,
    'accent': accent,
    'accentHover': accentHover,
    'textPrimary': textPrimary,
    'textSecondary': textSecondary,
    'sectionLabel': sectionLabel,
    'track': track,
    'trackBuffered': trackBuffered,
    'rowActive': rowActive,
    'windowButtonHover': windowButtonHover,
    'windowCloseHover': windowCloseHover,
    'titleBarScrim': titleBarScrim,
    'error': error,
  };
}

/// Non-colour design tokens.
abstract final class KyndrelTokens {
  /// Corner radius of translucent panels.
  static const double panelRadius = 24;

  /// Letter spacing for small-caps section labels.
  static const double sectionLabelLetterSpacing = 1.4;

  /// Height of the custom window title bar.
  static const double titleBarHeight = 48;

  /// Bundled UI font family (assets/fonts/Inter.ttf, SIL OFL 1.1).
  static const String fontFamily = 'Inter';

  /// Glyphs Inter lacks (Arabic, task 5.2) come from the bundled Noto.
  static const List<String> fontFamilyFallback = ['Noto Sans Arabic'];
}

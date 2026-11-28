import 'package:material_ui/material_ui.dart';

/// Kyndrel colour tokens (PLAN.md §1, "Theme tokens").
///
/// Every colour in the UI comes from here. Do not hard-code colours in
/// widgets.
abstract final class KyndrelColors {
  /// Near-black app and video background.
  static const Color background = Color(0xFF0B0B0D);

  /// Background of the "Pure black" setting, for OLED screens (task 8.8).
  static const Color black = Color(0xFF000000);

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

  /// Volume boost, from just above 100 % (orange) to the limit (red);
  /// Harbor's colours (task 9.1). Use [boost] for the value in between.
  static const Color boostLow = Color(0xFFF97316);
  static const Color boostHigh = Color(0xFFDC2626);

  /// The boost zone of an empty volume track: amber to red, faint.
  static const Color boostZoneLow = Color(0x2EF59E0B);
  static const Color boostZoneHigh = Color(0x42DC2626);

  /// The volume HUD's glass panel and its edge.
  static const Color glass = Color(0x59080C12);
  static const Color glassBorder = Color(0x26FFFFFF);
  static const Color glassEdge = Color(0x14FFFFFF);

  /// Colour of a boost [t] of the way (0–1) from 100 % to the limit.
  static Color boost(double t) =>
      Color.lerp(boostLow, boostHigh, t.clamp(0, 1).toDouble())!;

  /// Harbor's player buttons (task 9.2): the icon at rest (white 85 %),
  /// the hover circle (white 10 %) and the "on" circle (white 22 %).
  static const Color controlIdle = Color(0xD9FFFFFF);
  static const Color controlHover = Color(0x1AFFFFFF);
  static const Color controlActive = Color(0x38FFFFFF);

  /// The dot on a control whose feature is on (subtitles shown).
  static const Color indicator = Color(0xFF34D399);

  /// Harbor's scrims behind the top and bottom bars, strongest first.
  static const Color scrimBottom = Color(0xB3000000);
  static const Color scrimTop = Color(0x8C000000);
  static const Color scrimMiddle = Color(0x40000000);
  static const Color scrimFaint = Color(0x26000000);
  static const Color scrimClear = Color(0x00000000);

  /// Harbor's seek bar (task 9.3): its default amber, the colours the user
  /// can pick, the rainbow's six bands, the glass sheen and the stripes.
  static const Color seekAmber = Color(0xFFF4A25C);
  static const List<Color> seekColors = [
    seekAmber,
    accent,
    Color(0xFFFFFFFF),
    Color(0xFFEF4444),
    Color(0xFFEC4899),
    Color(0xFFA855F7),
    Color(0xFF3B82F6),
    Color(0xFF22D3EE),
    Color(0xFF22C55E),
    Color(0xFFFACC15),
  ];
  static const List<Color> rainbow = [
    Color(0xFFFF595E),
    Color(0xFFFF924C),
    Color(0xFFFFCA3A),
    Color(0xFF8AC926),
    Color(0xFF1982C4),
    Color(0xFF6A4C93),
  ];
  static const Color glassSheenTop = Color(0x47FFFFFF);
  static const Color glassSheenMid = Color(0x0AFFFFFF);
  static const Color glassSheenBottom = Color(0x2E000000);
  static const Color stripe = Color(0x38FFFFFF);

  /// Harbor's empty seek track (white 15 %) and buffered part (35 %).
  static const Color seekTrack = Color(0x26FFFFFF);
  static const Color seekBuffered = Color(0x59FFFFFF);

  /// The thumb's dark halo and drop shadow.
  static const Color dotHalo = Color(0x80000000);
  static const Color dotShadow = Color(0x73000000);

  /// Seek/volume track behind the progress fill.
  static const Color track = Color(0x33FFFFFF);

  /// Buffered segment on the seek bar.
  static const Color trackBuffered = Color(0x66FFFFFF);

  /// Highlight behind the active row in lists and popovers.
  static const Color rowActive = Color(0x29F26A1B);

  /// Hover background of the minimize/maximize buttons.
  static const Color windowButtonHover = Color(0x1FFFFFFF);

  /// Text on accent fills. White on the accent is only 3.1:1, below WCAG
  /// AA for body text; this near-black is 6.4:1 (task 5.3).
  static const Color onAccent = Color(0xFF0B0B0D);

  /// Keyboard focus highlight on controls (accent, 40 %).
  static const Color focus = Color(0x66F26A1B);

  /// Keyboard focus highlight on accent-filled buttons (white, 30 %).
  static const Color focusOnAccent = Color(0x4DFFFFFF);

  /// Hover background of the close button (Windows convention).
  static const Color windowCloseHover = Color(0xFFE81123);

  /// Top of the scrim behind the title bar, so it reads over bright video.
  static const Color titleBarScrim = Color(0xB3000000);

  /// Error text and icons.
  static const Color error = Color(0xFFFF5A5F);

  /// Accent, deeper: the edge of the plain disc label (task 7.6).
  static const Color accentPressed = Color(0xFFB8480C);

  /// The music view's record.
  static const Color vinyl = Color(0xFF101012);
  static const Color vinylGroove = Color(0x14FFFFFF);
  static const Color vinylEdge = Color(0x26FFFFFF);
  static const Color vinylSheen = Color(0x1AFFFFFF);

  /// The waves behind the front one.
  static const Color waveMiddle = Color(0x99F26A1B);
  static const Color waveBack = Color(0x4DF26A1B);

  /// The warm light behind the music view's record.
  static const Color musicGlow = Color(0x33F26A1B);

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
    'onAccent': onAccent,
    'focus': focus,
    'focusOnAccent': focusOnAccent,
    'windowCloseHover': windowCloseHover,
    'titleBarScrim': titleBarScrim,
    'error': error,
    'accentPressed': accentPressed,
    'vinyl': vinyl,
    'vinylGroove': vinylGroove,
    'vinylEdge': vinylEdge,
    'vinylSheen': vinylSheen,
    'waveMiddle': waveMiddle,
    'waveBack': waveBack,
    'musicGlow': musicGlow,
  };
}

/// Non-colour design tokens.
abstract final class KyndrelTokens {
  /// Corner radius of translucent panels.
  static const double panelRadius = 24;

  /// Corner radius of library thumbnails and tiles (task 7.4).
  static const double tileRadius = 8;

  /// Corner radius of small labels on thumbnails (length, NEW).
  static const double badgeRadius = 4;

  /// Letter spacing for small-caps section labels.
  static const double sectionLabelLetterSpacing = 1.4;

  /// Height of the custom window title bar.
  static const double titleBarHeight = 48;

  /// Bundled UI font family (assets/fonts/Inter.ttf, SIL OFL 1.1).
  static const String fontFamily = 'Inter';

  /// Glyphs Inter lacks (Arabic, task 5.2) come from the bundled Noto.
  static const List<String> fontFamilyFallback = ['Noto Sans Arabic'];
}

import 'package:flutter/foundation.dart';

/// User subtitle appearance (task 2.8), applied through mpv's `sub-*`
/// options so it also works for embedded tracks.
@immutable
class SubtitleStyle {
  const new({
    this.font = 'Inter',
    this.size = 46,
    this.color = 0xFFFFFFFF,
    this.outlineColor = 0xFF000000,
    this.outlineSize = 2.5,
    this.backgroundBox = false,
    this.backgroundColor = 0x99000000,
    this.position = 96,
    this.bold = false,
    this.overrideAssStyles = false,
  });

  factory fromJson(Map<String, Object?> json) {
    const d = SubtitleStyle();
    return SubtitleStyle(
      font: json['font'] as String? ?? d.font,
      size: (json['size'] as num?)?.toDouble() ?? d.size,
      color: json['color'] as int? ?? d.color,
      outlineColor: json['outlineColor'] as int? ?? d.outlineColor,
      outlineSize: (json['outlineSize'] as num?)?.toDouble() ?? d.outlineSize,
      backgroundBox: json['backgroundBox'] as bool? ?? d.backgroundBox,
      backgroundColor: json['backgroundColor'] as int? ?? d.backgroundColor,
      position: json['position'] as int? ?? d.position,
      bold: json['bold'] as bool? ?? d.bold,
      overrideAssStyles:
          json['overrideAssStyles'] as bool? ?? d.overrideAssStyles,
    );
  }

  final String font;

  /// mpv `sub-font-size` (scaled to a 720 px tall window).
  final double size;

  /// ARGB colours.
  final int color;
  final int outlineColor;
  final double outlineSize;
  final bool backgroundBox;
  final int backgroundColor;

  /// mpv `sub-pos`: 0 = top, 100 = bottom.
  final int position;
  final bool bold;

  /// Also restyle ASS/SSA subtitles (mpv `sub-ass-override=force`).
  final bool overrideAssStyles;

  static const fonts = [
    'Inter',
    'Arial',
    'Helvetica',
    'Verdana',
    'Segoe UI',
    'Noto Sans',
    'Times New Roman',
  ];

  /// mpv option values for this style.
  Map<String, String> toMpvOptions() => {
    'sub-font': font,
    'sub-font-size': size.toStringAsFixed(0),
    'sub-color': mpvColor(color),
    'sub-border-color': mpvColor(
      backgroundBox ? backgroundColor : outlineColor,
    ),
    'sub-border-size': backgroundBox ? '0' : outlineSize.toStringAsFixed(1),
    'sub-back-color': mpvColor(backgroundBox ? backgroundColor : 0x00000000),
    'sub-border-style': backgroundBox ? 'opaque-box' : 'outline-and-shadow',
    'sub-pos': '$position',
    'sub-bold': bold ? 'yes' : 'no',
    'sub-ass-override': overrideAssStyles ? 'force' : 'scale',
  };

  /// ARGB int to mpv's `#AARRGGBB`.
  static String mpvColor(int argb) =>
      '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';

  Map<String, Object?> toJson() => {
    'font': font,
    'size': size,
    'color': color,
    'outlineColor': outlineColor,
    'outlineSize': outlineSize,
    'backgroundBox': backgroundBox,
    'backgroundColor': backgroundColor,
    'position': position,
    'bold': bold,
    'overrideAssStyles': overrideAssStyles,
  };

  SubtitleStyle copyWith({
    String? font,
    double? size,
    int? color,
    int? outlineColor,
    double? outlineSize,
    bool? backgroundBox,
    int? backgroundColor,
    int? position,
    bool? bold,
    bool? overrideAssStyles,
  }) {
    return SubtitleStyle(
      font: font ?? this.font,
      size: size ?? this.size,
      color: color ?? this.color,
      outlineColor: outlineColor ?? this.outlineColor,
      outlineSize: outlineSize ?? this.outlineSize,
      backgroundBox: backgroundBox ?? this.backgroundBox,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      position: position ?? this.position,
      bold: bold ?? this.bold,
      overrideAssStyles: overrideAssStyles ?? this.overrideAssStyles,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SubtitleStyle && mapEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}

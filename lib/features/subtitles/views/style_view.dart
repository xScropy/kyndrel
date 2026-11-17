import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/core/player/subtitle_style.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:material_ui/material_ui.dart';

/// Font, size, colours, outline, background box and position, with a live
/// preview (task 2.8). Saved in settings; the app shell applies it to mpv.
class StyleView extends ConsumerWidget {
  const new({super.key});

  static const textColors = [
    0xFFFFFFFF, 0xFFFFEB3B, 0xFFF26A1B, 0xFF4FC3F7, 0xFF8BC34A, 0xFFE0E0E0, //
  ];
  static const outlineColors = [0xFF000000, 0xFF333333, 0xFF1A237E];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(settingsProvider.select((s) => s.subtitleStyle));
    void update(SubtitleStyle Function(SubtitleStyle) change) => unawaited(
      ref
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(subtitleStyle: change(s.subtitleStyle))),
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SubtitlePreview(style: style),
          const SizedBox(height: 12),
          _Row(
            label: 'Font',
            child: DropdownButton<String>(
              key: const Key('style-font'),
              isExpanded: true,
              value: SubtitleStyle.fonts.contains(style.font)
                  ? style.font
                  : SubtitleStyle.fonts.first,
              dropdownColor: KyndrelColors.surface,
              items: [
                for (final f in SubtitleStyle.fonts)
                  DropdownMenuItem(value: f, child: Text(f)),
              ],
              onChanged: (f) => update((s) => s.copyWith(font: f)),
            ),
          ),
          _Row(
            label: 'Size',
            child: Slider(
              key: const Key('style-size'),
              min: 24,
              max: 90,
              value: style.size.clamp(24, 90),
              label: style.size.round().toString(),
              onChanged: (v) =>
                  update((s) => s.copyWith(size: v.roundToDouble())),
            ),
          ),
          _Row(
            label: 'Colour',
            child: _Swatches(
              keyPrefix: 'style-color',
              colors: textColors,
              selected: style.color,
              onSelected: (c) => update((s) => s.copyWith(color: c)),
            ),
          ),
          _Row(
            label: 'Bold',
            child: Align(
              alignment: Alignment.centerLeft,
              child: Switch(
                value: style.bold,
                onChanged: (v) => update((s) => s.copyWith(bold: v)),
              ),
            ),
          ),
          _Row(
            label: 'Background box',
            child: Align(
              alignment: Alignment.centerLeft,
              child: Switch(
                key: const Key('style-box'),
                value: style.backgroundBox,
                onChanged: (v) => update((s) => s.copyWith(backgroundBox: v)),
              ),
            ),
          ),
          if (!style.backgroundBox) ...[
            _Row(
              label: 'Outline',
              child: _Swatches(
                keyPrefix: 'style-outline',
                colors: outlineColors,
                selected: style.outlineColor,
                onSelected: (c) => update((s) => s.copyWith(outlineColor: c)),
              ),
            ),
            _Row(
              label: 'Outline size',
              child: Slider(
                min: 0,
                max: 6,
                divisions: 12,
                value: style.outlineSize.clamp(0, 6),
                label: style.outlineSize.toStringAsFixed(1),
                onChanged: (v) => update((s) => s.copyWith(outlineSize: v)),
              ),
            ),
          ] else
            _Row(
              label: 'Box opacity',
              child: Slider(
                min: 0.2,
                max: 1,
                value: ((style.backgroundColor >> 24) / 255).clamp(0.2, 1),
                onChanged: (v) => update(
                  (s) => s.copyWith(
                    backgroundColor: ((v * 255).round() << 24) | 0x000000,
                  ),
                ),
              ),
            ),
          _Row(
            label: 'Position',
            child: Slider(
              key: const Key('style-position'),
              min: 50,
              max: 100,
              value: style.position.clamp(50, 100).toDouble(),
              label: '${style.position}',
              onChanged: (v) => update((s) => s.copyWith(position: v.round())),
            ),
          ),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: style.overrideAssStyles,
            onChanged: (v) =>
                update((s) => s.copyWith(overrideAssStyles: v ?? false)),
            title: const Text('Also restyle styled (ASS/SSA) subtitles'),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('style-reset'),
              onPressed: () => update((_) => const SubtitleStyle()),
              child: const Text('Reset to default'),
            ),
          ),
          const Text(
            'Image subtitles (PGS, VobSub) keep their own look.',
            style: TextStyle(fontSize: 11, color: KyndrelColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Approximates how mpv will draw the subtitle, on a stand-in frame.
class SubtitlePreview extends StatelessWidget {
  const new({required this.style, super.key});

  final SubtitleStyle style;

  @override
  Widget build(BuildContext context) {
    const height = 150.0;
    // mpv's sub-font-size is relative to a 720 px tall window.
    final fontSize = style.size * height / 720 * 1.6;
    final textStyle = TextStyle(
      fontFamily: style.font,
      fontSize: fontSize,
      fontWeight: style.bold ? FontWeight.w700 : FontWeight.w500,
      color: Color(style.color),
      height: 1.15,
    );
    final text = Text(
      'The quick brown fox\njumps over the lazy dog',
      key: const Key('subtitle-preview-text'),
      textAlign: TextAlign.center,
      style: textStyle,
    );
    final outlined = style.backgroundBox || style.outlineSize == 0
        ? text
        : Stack(
            children: [
              Text(
                'The quick brown fox\njumps over the lazy dog',
                textAlign: TextAlign.center,
                style: textStyle.copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = style.outlineSize * 1.2
                    ..color = Color(style.outlineColor),
                ),
              ),
              text,
            ],
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        key: const Key('subtitle-preview'),
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A5A78), Color(0xFF1E2A33), Color(0xFF6B4F3A)],
          ),
        ),
        child: Align(
          alignment: Alignment(0, (style.position - 50) / 50 * 0.9),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            color: style.backgroundBox ? Color(style.backgroundColor) : null,
            child: outlined,
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const new({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label.toUpperCase(), style: KyndrelTheme.sectionLabel),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Swatches extends StatelessWidget {
  const new({
    required this.keyPrefix,
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  final String keyPrefix;
  final List<int> colors;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final c in colors)
          GestureDetector(
            key: Key('$keyPrefix-${c.toRadixString(16)}'),
            onTap: () => onSelected(c),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: c == selected
                      ? KyndrelColors.accent
                      : KyndrelColors.panelBorder,
                  width: c == selected ? 3 : 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

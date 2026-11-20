import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('accent is the brand orange', () {
    expect(KyndrelColors.accent, const Color(0xFFF26A1B));
  });

  test('theme uses the tokens', () {
    final theme = KyndrelTheme.dark();
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, KyndrelColors.accent);
    expect(theme.scaffoldBackgroundColor, KyndrelColors.background);
    expect(theme.textTheme.bodyMedium?.fontFamily, KyndrelTokens.fontFamily);
  });

  testWidgets('colour tokens golden', (tester) async {
    tester.view
      ..physicalSize = const Size(640, 860)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: KyndrelTheme.dark(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('COLOUR TOKENS', style: KyndrelTheme.sectionLabel),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final e in KyndrelColors.all.entries)
                      _Swatch(name: e.key, color: e.value),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: KyndrelTheme.panelDecoration(),
                  child: const Text('Panel · 24 px radius · Inter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/kyndrel_colors.png'),
    );
  });
}

class _Swatch extends StatelessWidget {
  const new({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hex = color.toARGB32().toRadixString(16).padLeft(8, '0');
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: KyndrelColors.panelBorder),
            ),
          ),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(fontSize: 12)),
          Text(
            '#${hex.toUpperCase()}',
            style: const TextStyle(
              fontSize: 11,
              color: KyndrelColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

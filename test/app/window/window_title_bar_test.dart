import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/theme/kyndrel_colors.dart';
import 'package:kyndrel/app/theme/kyndrel_theme.dart';
import 'package:kyndrel/app/window/window_title_bar.dart';
import 'package:kyndrel/core/platform/window_service.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_window_service.dart';

void main() {
  late FakeWindowService window;

  Future<void> pumpBar(
    WidgetTester tester, {
    bool maximized = false,
    Widget? child,
  }) async {
    window = FakeWindowService(maximized: maximized);
    tester.view
      ..physicalSize = const Size(800, 120)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [windowServiceProvider.overrideWithValue(window)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: KyndrelTheme.dark(),
          home: Scaffold(
            backgroundColor: const Color(0xFF3A6EA5), // stand-in for video
            body: Align(
              alignment: Alignment.topCenter,
              child: WindowTitleBar(child: child),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('buttons minimize, maximize and close', (tester) async {
    await pumpBar(tester);
    await tester.tap(find.byKey(const Key('window-minimize')));
    await tester.tap(find.byKey(const Key('window-maximize')));
    await tester.tap(find.byKey(const Key('window-close')));
    expect(window.calls, ['minimize', 'toggleMaximize', 'close']);
  });

  testWidgets('maximize icon switches to restore when maximized', (
    tester,
  ) async {
    await pumpBar(tester);
    expect(find.byIcon(Icons.crop_square), findsOneWidget);
    expect(find.byTooltip('Maximize'), findsOneWidget);

    await tester.tap(find.byKey(const Key('window-maximize')));
    await tester.pump();
    expect(find.byIcon(Icons.filter_none), findsOneWidget);
    expect(find.byTooltip('Restore'), findsOneWidget);
  });

  testWidgets('starts in restore state when the window is maximized', (
    tester,
  ) async {
    await pumpBar(tester, maximized: true);
    expect(find.byIcon(Icons.filter_none), findsOneWidget);
  });

  testWidgets('dragging the bar moves the window', (tester) async {
    await pumpBar(tester);
    await tester.drag(
      find.byKey(const Key('title-bar-drag-area')),
      const Offset(60, 20),
    );
    await tester.pump(kDoubleTapTimeout);
    expect(window.calls, ['startDragging']);
  });

  testWidgets('double-clicking the bar toggles maximize', (tester) async {
    await pumpBar(tester);
    final area = find.byKey(const Key('title-bar-drag-area'));
    await tester.tap(area);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(area);
    await tester.pumpAndSettle();
    expect(window.calls, ['toggleMaximize']);
  });

  testWidgets('the child area is draggable too', (tester) async {
    await pumpBar(tester, child: const Center(child: Text('Title')));
    await tester.drag(find.text('Title'), const Offset(40, 0));
    await tester.pump(kDoubleTapTimeout);
    expect(window.calls, ['startDragging']);
  });

  testWidgets('close button turns red on hover', (tester) async {
    await pumpBar(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('window-close'))));
    await tester.pumpAndSettle();

    final box = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const Key('window-close')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = box.decoration as BoxDecoration?;
    expect(decoration?.color, KyndrelColors.windowCloseHover);

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/window_title_bar_close_hover.png'),
    );
  });

  testWidgets('title bar golden', (tester) async {
    await pumpBar(tester);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/window_title_bar.png'),
    );
  });
}

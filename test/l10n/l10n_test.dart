import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyndrel/app/launch_options.dart';
import 'package:kyndrel/core/storage/settings.dart';
import 'package:kyndrel/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../support/app_harness.dart';

Map<String, Object?> _arb(String locale) =>
    (jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Map)
        .cast<String, Object?>();

Set<String> _placeholders(String s) =>
    RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m[1]!).toSet();

void main() {
  group('ARB files', () {
    final en = _arb('en');
    final ar = _arb('ar');
    final keys = en.keys.where((k) => !k.startsWith('@')).toSet();

    test('Arabic translates every English string', () {
      final arKeys = ar.keys.where((k) => !k.startsWith('@')).toSet();
      expect(arKeys.difference(keys), isEmpty, reason: 'unknown keys');
      expect(keys.difference(arKeys), isEmpty, reason: 'missing in ar');
    });

    test('translations keep the same placeholders and are not empty', () {
      for (final k in keys) {
        final e = en[k]! as String;
        final a = ar[k]! as String;
        expect(a.trim(), isNotEmpty, reason: k);
        expect(_placeholders(a), _placeholders(e), reason: k);
      }
    });
  });

  test('language setting maps to a locale', () {
    expect(L10n.localeFor('system'), isNull);
    expect(L10n.localeFor('ar'), const Locale('ar'));
    expect(
      L10n.supportedLocales.map((l) => l.languageCode),
      containsAll(['en', 'ar']),
    );
  });

  testWidgets('Arabic: RTL layout, translated strings, LTR timeline', (
    tester,
  ) async {
    final h = await AppHarness.create(prefs: {'language': 'ar'});
    await h.pump(tester, launch: const LaunchOptions(source: '/v/film.mkv'));
    h.load();
    await tester.pump();

    final page = tester.element(find.byKey(const Key('play-pause')));
    expect(Localizations.localeOf(page).languageCode, 'ar');
    // The transport keeps tape direction…
    expect(Directionality.of(page), TextDirection.ltr);
    // …while the page itself is right-to-left.
    final top = tester.element(find.byKey(const Key('top-back')));
    expect(Directionality.of(top), TextDirection.rtl);

    // Side groups mirror: volume moves to the right, cast/fullscreen left.
    final mute = tester.getCenter(find.byKey(const Key('mute')));
    final full = tester.getCenter(find.byKey(const Key('fullscreen')));
    expect(mute.dx, greaterThan(full.dx));

    // The seek bar still runs left to right: elapsed time on the left.
    final seek = tester.element(find.byKey(const Key('seek-bar')));
    expect(Directionality.of(seek), TextDirection.ltr);

    // Strings come from app_ar.arb.
    final ar = lookupAppLocalizations(const Locale('ar'));
    expect(find.byTooltip(ar.fullscreenTooltip), findsOneWidget);
    expect(find.byTooltip(ar.mediaInfo), findsOneWidget);
    // Material's own strings are Arabic too.
    expect(MaterialLocalizations.of(page).okButtonLabel, isNot('OK'));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/player_page_ar.png'),
    );
  });

  testWidgets('switching the language setting relocalises live', (
    tester,
  ) async {
    final h = await AppHarness.create();
    await h.pump(tester);
    final en = lookupAppLocalizations(const Locale('en'));
    expect(find.text(en.openMediaHeader), findsOneWidget);

    await h.container
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(language: 'ar'));
    await tester.pump();
    final ar = lookupAppLocalizations(const Locale('ar'));
    expect(find.text(ar.openMediaHeader), findsOneWidget);
    expect(find.text(en.openMediaHeader), findsNothing);
    expect(h.settings.load().language, 'ar');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/start_screen_ar.png'),
    );
  });
}

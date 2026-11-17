# Localisation (task 5.2)

Kyndrel ships in **English** and **Arabic** (`Settings › Language`:
System / English / العربية). The choice applies immediately.

## How it works
- Strings live in `lib/l10n/app_en.arb` (template) and `lib/l10n/app_ar.arb`.
- `flutter gen-l10n` (also run by `flutter pub get`, since `generate: true`)
  writes `lib/l10n/gen/`. The generated files are committed so the analyzer
  and CI work without a codegen step; they are excluded from lints.
- Widgets use `context.l10n.someKey` (`lib/l10n/l10n.dart`). It falls back
  to English when no localisations are in scope (bare widget tests).
- `L10n.delegates` combines the app strings with **material_ui's**
  `GlobalMaterialLocalizations.delegates`. Don't use the generated
  `AppLocalizations.localizationsDelegates`: it points at the deprecated
  `package:flutter/material.dart` types, which material_ui doesn't read.

## Adding a string
1. Add the key to `app_en.arb` (with `@key.placeholders` if it has any).
2. Add the translation to `app_ar.arb`.
3. `flutter gen-l10n`, then use `context.l10n.key`.

`test/l10n/l10n_test.dart` fails if a key is missing from a translation
or its placeholders differ.

## Right-to-left rules
- The page mirrors: the volume/download group moves to the right, and
  panels and popovers anchor from the other side (`PositionedDirectional`,
  `AlignmentDirectional`, and `Popover` swaps left and right).
- **Timelines are not mirrored.** Following Material's bidirectionality
  guidance, the seek bar, the transport (back / play / forward), the volume
  slider and "continue watching" progress stay left-to-right, because they
  represent the direction time moves on the media.
- Write new layout with start/end (`EdgeInsetsDirectional`,
  `AlignmentDirectional`), not left/right.

## Coverage
Translated: the player chrome (top bar, seek bar, transport, volume,
fullscreen, fit/zoom/rotate, speed & sleep, the subtitle/audio panel's main
view, queue panel, resume banner, start screen, library home, window
buttons, context menu, drop overlay, diagnostics) and the settings page
navigation and Language section.

Still English (follow-up): the individual settings rows, subtitle style and
sync views, online subtitle results, media info, edit details, open-URL /
WebDAV dialog, download, cast, translate and effects dialogs, OSD messages,
and error texts produced in `core/`. Adding them is mechanical with the
steps above.

## Fonts
Inter has no Arabic glyphs, so the theme falls back to the bundled
**Noto Sans Arabic** (`assets/fonts/NotoSansArabic.ttf`, SIL OFL 1.1,
licence beside it) via `KyndrelTokens.fontFamilyFallback`. Goldens:
`test/l10n/goldens/player_page_ar.png`, `start_screen_ar.png`.

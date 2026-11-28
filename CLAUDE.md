# Kyndrel
Flutter video player on libmpv via media_kit. Dark UI, orange accent (#F26A1B).
- Only core/player/PlayerService touches libmpv. UI uses Riverpod providers.
  media_kit is imported only in `core/player/media_kit_backend.dart` and
  `core/player/player_video_view.dart`.
- Max volume is 500 (volume-max=500). Slider range 0..500 (100 % at 64 % of the track, as in Harbor; the top is the "Boost limit" setting).
- Follow PLAN.md; do tasks in order and tick the checkbox when done.
- Before finishing a task: `flutter analyze` and `flutter test` must pass.
- Keep commits small, one task per commit, message format: `feat(subtitles): load external file (2.6)`.

## Layout
- `core/`: player (service, backend, state, providers), storage (settings
  in shared_preferences, resume points in Drift), platform (window), ui
  (popover, OSD, controls visibility, buttons), utils (titles, languages,
  time).
- `features/<name>/`: no imports between features. `lib/app/player_page.dart`
  is the one place that composes features (bottom-right buttons, panels,
  shortcuts in `player_shortcuts.dart`, settings → engine in
  `engine_sync.dart`).

## Conventions
- Colours and radii come from `lib/app/theme/kyndrel_colors.dart`; never hard-code them in widgets.
- Flutter 3.50 / Dart 3.14: Material is imported from `package:material_ui/material_ui.dart`,
  and constructors use the `const new(...)` form (`dart fix --apply` handles it).
- Lints: `very_good_analysis` (see `analysis_options.yaml`).
- Every mpv property or command used goes in `docs/mpv-properties.md`.
- Don't change Riverpod state in `initState`/`build`/`dispose`; defer to a
  post-frame callback.
- Goldens live next to their tests in `goldens/`. Regenerate with
  `flutter test --update-goldens` only for intended visual changes.
- `window_manager` is pinned to 0.5.x (0.7 is a native-assets rewrite).
- Drift code is generated: `dart run build_runner build` after editing
  `core/storage/database.dart`.

## Tests
- Unit/widget tests drive `PlayerService` through
  `test/support/fake_player_backend.dart`; full-page tests use
  `test/support/app_harness.dart`. Create services inside the test body (not
  `setUp`) in widget tests so streams run in the fake-async zone.
- `test/flutter_test_config.dart` loads Inter and the Material icon font for
  every test, so goldens show real glyphs.
- Real-engine tests (`test/engine/`, tag `engine`) are skipped by default:
  `scripts/make_test_media.sh && flutter test -t engine --run-skipped`.
- Linux SQLite comes from the system (`hooks.user_defines` in pubspec), so
  Linux needs `libsqlite3-dev`.

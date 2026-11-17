# Kyndrel
Flutter video player on libmpv via media_kit. Dark UI, orange accent (#F26A1B).
- Only core/player/PlayerService touches libmpv. UI uses Riverpod providers.
  media_kit is imported only in `core/player/media_kit_backend.dart` and
  `core/player/player_video_view.dart`.
- Max volume is 400 (volume-max=400). Slider range 0..400.
- Follow PLAN.md; do tasks in order and tick the checkbox when done.
- Before finishing a task: `flutter analyze` and `flutter test` must pass.
- Keep commits small, one task per commit, message format: `feat(subtitles): load external file (2.6)`.

## Conventions
- Colours and radii come from `lib/app/theme/kyndrel_colors.dart`; never hard-code them in widgets.
- Flutter 3.50 / Dart 3.14: Material is imported from `package:material_ui/material_ui.dart`,
  and constructors use the `const new(...)` form (`dart fix --apply` handles it).
- Lints: `very_good_analysis` (see `analysis_options.yaml`).
- Every mpv property or command used goes in `docs/mpv-properties.md`.
- Goldens live next to their tests in `goldens/`. Regenerate with
  `flutter test --update-goldens` only for intended visual changes.
- `window_manager` is pinned to 0.5.x (0.7 is a native-assets rewrite).
- Tests drive `PlayerService` through `test/support/fake_player_backend.dart`.
  In widget tests, create the service inside the test body (not `setUp`) so
  its streams run in the fake-async zone.

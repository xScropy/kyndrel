# Accessibility (task 5.3)

## Keyboard
- Every action has a shortcut (Settings › Shortcuts lists and rebinds them).
- **Tab** walks the controls in reading order: top bar (back, media info),
  the seek bar's time toggle, then the bottom row from start to end (volume,
  download, back/play/forward, queue, fit, translate, subtitles, speed,
  picture-in-picture, cast, full screen). Shift+Tab goes back; Enter or
  Space activates the focused control.
- Focused controls draw an accent highlight (`KyndrelColors.focus`; white on
  the orange play button).
- While a control has keyboard focus the overlay stays up, so focus never
  sits on a hidden button. Moving or clicking the mouse hands back to the
  normal auto-hide (`KeyboardFocusKeepsControls` in `player_page.dart`).

## Screen readers
- Control buttons are buttons labelled with their tooltip ("Pause",
  "Mute (M)", …), translated with the UI.
- The seek bar is a slider labelled "Seek" whose value reads
  "12:04 of 1:42:10"; the screen reader's increase/decrease gestures seek by
  the skip interval.
- The volume slider is a slider labelled "Volume" with the percentage.
- The video surface says what tapping does ("Tap to show controls,
  double-tap for full screen").

## Contrast
- `test/a11y/accessibility_test.dart` runs Flutter's
  `textContrastGuideline` (WCAG AA, 4.5:1 for body text) and
  `labeledTapTargetGuideline` on the player (English and Arabic), the start
  screen and the settings page.
- This found white text on the orange accent at 3.1:1. Text on accent fills
  now uses `KyndrelColors.onAccent` (near-black, 6.4:1). White icons on the
  play button are kept: non-text elements need 3:1.

## Not covered
- Popover and panel contents aren't in the Tab ring until opened, and
  arrow-key navigation inside lists is Flutter's default.
- Screen reader behaviour was checked through the semantics tree in tests,
  not with NVDA, VoiceOver or Orca on real machines.

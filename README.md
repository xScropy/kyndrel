# Kyndrel

A modern desktop-first video player built on **libmpv** (via
[media_kit](https://github.com/media-kit/media-kit)) with a dark,
orange-accented Flutter UI.

> Status: Phases 0–2 of [PLAN.md](PLAN.md) are done (core player, speed &
> sleep, subtitles and audio). Open items are listed in PLAN.md.

## Features

- Plays what mpv plays: MP4, MKV, AVI, WebM, HLS, HEVC…, with hardware
  decoding (`hwdec=auto-safe`).
- Frameless window with custom title bar, top bar with title, year and
  quality badge, media info dialog.
- Seek bar with buffered range and hover time; ±10 s (configurable) skips.
- Volume up to **400 %** with a limiter above 100 %.
- Speed 0.5–2× (or any 0.1–4×) with pitch correction; sleep timer with
  fade-out, "end of episode" and "end of next episode".
- Subtitles & audio panel: embedded, image (PGS/VobSub) and external
  tracks, auto-loading of `Film.en.srt`-style files, sync offsets, dual
  subtitles, style with live preview, and OpenSubtitles search/download.
- Fit / Fill / Stretch / 16:9 / 4:3 / Original, zoom and rotate.
- Resume where you left off; open by file picker, drag-and-drop, paste,
  command line or "Open with".

## Keyboard

| Key | Action |
|---|---|
| Space | Play / pause |
| ← / → | Seek by the skip length |
| ↑ / ↓ | Volume ±5 % |
| M | Mute |
| F, double-click | Full screen |
| Esc | Close panel / leave full screen |
| [ / ] | Slower / faster |
| S | Subtitles & audio |
| Ctrl+O / Ctrl+V | Open file / open pasted path or URL |
| Ctrl+I / Ctrl+, | Media info / settings |

Mouse: click to play/pause, scroll to change volume, right-click for a menu.
Touch: tap to show controls, drag sideways to seek.

## Build

Requires Flutter 3.50 (stable).

```sh
flutter pub get
flutter run -d windows            # or -d linux / -d macos
flutter run -d windows -- <file>  # open a file on start
flutter run -d windows -- --diagnostics <file>   # show decoder stats
```

Linux needs libmpv, SQLite and the usual desktop toolchain:

```sh
sudo apt install libmpv-dev mpv libsqlite3-dev clang cmake ninja-build pkg-config libgtk-3-dev
```

Online subtitles need a free OpenSubtitles API key (Settings, Ctrl+,).

## Checks

```sh
flutter analyze
flutter test                                   # unit, widget and golden tests
scripts/make_test_media.sh                     # needs ffmpeg, python3-pil
flutter test -t engine --run-skipped           # against the real libmpv
```

CI runs all three and builds a Windows artifact.

## Licence

Kyndrel is licensed under the **GNU GPL v3.0** (see [LICENSE](LICENSE)).

GPL-3.0 was chosen because it is compatible with both GPL and LGPL builds of
libmpv/FFmpeg, so the bundled engine build can be chosen freely. A licence
audit of the shipped binaries is planned for task 5.8 (`ATTRIBUTION.md`).

The bundled Inter font is under the SIL Open Font License 1.1
(`assets/fonts/OFL.txt`).

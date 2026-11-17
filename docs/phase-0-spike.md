# Phase 0 spike: manual check (task 0.5)

Since task 1.1 the spike screen is gone; the same check runs in the real
player with the `--diagnostics` flag, which shows a panel of live mpv
properties.

## Run

```sh
flutter run -d windows -- --diagnostics "C:\path\to\clip.mkv"
# or start with no argument and paste a path/URL into the field
```

Linux needs the system libmpv: `sudo apt install libmpv-dev mpv`.

## What to confirm

1. Video plays with sound; seeking with the default controls works.
2. The panel says **Hardware decoding: d3d11va** (or `nvdec`, `dxva2`,
   `vaapi`, `videotoolbox`...). "Software decoding" for an H.264/HEVC file
   on a machine with a modern GPU means hwdec is not working.
3. `frame-drop-count` stays at or near 0 for a 4K HEVC clip.

Record results (OS, GPU, file, hwdec value, drops) in the table below.

| Date | OS | GPU | File | hwdec-current | Drops | Notes |
|---|---|---|---|---|---|---|
| | | | | | | |

## Results so far

- 2026-11-17, Ubuntu 24.04 container under Xvfb, no GPU, 720p H.264 test
  clip: plays, `hwdec-current: no` (expected without a GPU). Screenshot:
  `docs/screenshots/`. Hardware decoding still to be confirmed on
  Windows.
- Local Linux builds in a sandbox that cannot download from github.com fail on
  media_kit_libs_linux's mimalloc fetch. Workaround: install
  `libmimalloc-dev` and add `set(MIMALLOC_USE_STATIC_LIBS OFF CACHE BOOL "" FORCE)`
  before `project(` in `linux/CMakeLists.txt` (not committed; normal machines
  don't need it).
- 2026-11-17, same container: Phases 1–2 verified against libmpv 0.37 with
  `flutter test -t engine --run-skipped` (MP4, MKV, AVI, WebM, HLS, HEVC,
  tracks, PGS, volume 400 %, speed) and a driven Linux build (screenshots in
  `docs/screenshots/`, including a PGS subtitle rendered by mpv).

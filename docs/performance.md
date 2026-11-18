# Performance (task 5.4)

## What keeps the UI cheap
- **The video is its own layer** (`RepaintBoundary` keyed `video-layer` in
  `player_page.dart`). Nothing in the overlay can make Flutter repaint the
  video texture's layer.
- **The overlays fade by compositing.** The top and bottom bars sit in
  `AnimatedOpacity` over a `RepaintBoundary`, so the 200 ms fade only
  changes an opacity value; neither the controls nor the video repaint.
- **Position ticks touch only the seek row.** The seek row has a fixed
  height (`SeekBarRow.height`), which makes it a relayout boundary, and its
  own `RepaintBoundary`. Before this, every tick laid out and repainted the
  whole bottom bar (a relayout always marks the object for repaint).
- The time labels use tabular figures at fixed widths, so the row never
  changes size.

`test/perf/repaint_test.dart` locks this in. It compares the layers each
boundary recorded before and after 20 position ticks and a full fade: the
video's and the bar's layers must be the same objects, and the seek row's
must change. (`RenderRepaintBoundary.debugAsymmetricPaintCount` isn't used:
it also counts frames where only the parent painted.)

## Measuring
`--perf-log` makes the app print `kyndrel-perf <event> <epoch ms> [value]`
on stderr: `main`, `first-frame`, `first-video-frame`, then every 10 s
`rss-mb`, `dropped-frames` (mpv `frame-drop-count`) and `fps`
(`estimated-vf-fps`).

`scripts/perf_probe.sh <binary> <media> [seconds]` launches a build with
that flag, samples CPU (from `/proc/<pid>/stat`) and RSS every 2 s, and
prints a summary. Linux only; on a headless machine wrap it in `xvfb-run`.

```sh
flutter build linux --release
scripts/perf_probe.sh build/linux/x64/release/bundle/kyndrel film.mkv 10800
```

## Results so far
Release build on a 4-core Xeon VM, **no GPU** (Xvfb, software rendering
and software decoding), libmpv 0.37. CPU and the 4K numbers are therefore
worst cases; on real hardware mpv decodes with the GPU (`hwdec=auto-safe`).

| Clip | Start → first frame | Start → first video frame | CPU (of 400 %) | RSS | Dropped |
|---|---|---|---|---|---|
| 4K H.264 30 fps, 40 s | 311 ms | 692 ms | 200 % | 549 → 569 MB | 1, at start |
| 1080p H.264 24 fps, 5 min | 300 ms | 928 ms | 114 % | 429 → 452 MB | 6 in 5 min |
| 720p H.264 24 fps, 25 min | SOAK_FRAME | SOAK_VIDEO | SOAK_CPU | SOAK_RSS | SOAK_DROPPED |

Cold start, with nothing in the OS file cache, was 1.1 s to the first
frame. Both clips played at their full frame rate.

SOAK_NOTE

## Still to measure on real machines
- **Memory over a 3-hour film:** run the probe for 10 800 s on Windows,
  macOS and Linux desktops (macOS/Windows need the `/proc` parts swapped
  for `ps`/`Get-Process`).
- **CPU in 4K with hardware decoding:** expect single-digit percent with
  `hwdec` active; the diagnostics overlay (`--diagnostics`) shows which
  decoder mpv chose.
- **Frame pacing while the overlay animates:** run
  `flutter run --profile` and watch the raster thread in DevTools during a
  fade. The layer structure above means the fade should cost one
  composite per frame.

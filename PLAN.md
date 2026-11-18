# Kyndrel: Project Plan

A modern desktop-first video player on a libmpv engine (VLC-class playback), with a dark, orange-accented UI.

## 0. Decisions

| Area | Choice |
|---|---|
| Name / repo | Kyndrel (`kyndrel`) |
| Engine | libmpv (FFmpeg-based, hardware decoding, nearly every format) |
| UI | Flutter + `media_kit`, `media_kit_video`, `media_kit_libs_video` |
| Targets | Windows first, then Linux and macOS, then Android/iOS |
| State management | Riverpod |
| Persistence | Drift (SQLite) for history, resume points and playlists; `shared_preferences` for settings |
| Windowing | `window_manager` (frameless window, PiP, always-on-top) |
| Licence | GPL-3.0 with a GPL libmpv build, or MIT/Apache-2.0 with an LGPL build |

Fallback: Qt 6/QML + libmpv if Flutter's video texture path proves limiting on a target.

## 1. UI spec (from the reference screenshots)

**Top bar:** back arrow, title, year under the title, quality badge (e.g. `480P`), info icon (opens media-info dialog), minimize/maximize/close on the right. The bar is draggable and auto-hides.

**Seek bar:** orange progress bar with a round thumb and elapsed time on the left and total/remaining time on the right. Clicking or dragging seeks, and hovering shows a time tooltip.

**Bottom-left:** mute/volume icon, volume slider, orange percentage readout (e.g. `255%`), download button.
- **Maximum volume is 400%, not 255%.** The slider covers 0–400 with a visual marker at 100%. The part above 100% is drawn in the accent colour to show it is boosted.

**Bottom-centre:** back 10 s, large circular play/pause, forward 10 s.

**Bottom-right (left to right):** fit/aspect icon, subtitle-translate icon, subtitles icon, speed button showing the current rate (`1.25×`), picture-in-picture, cast, exit fullscreen.

**Speed & sleep popover (tooltip "Speed & sleep"):** two columns.
- Playback speed: 0.5×, 0.75×, Normal (marked DEFAULT), 1.25×, 1.5×, 1.75×, 2×. The active row is highlighted.
- Sleep timer: 15 min, 30 min, 45 min, 1 hour, 2, 3, 4, 6 hours, End of episode, End of next episode.

**Subtitles panel:** header with sync-offset (timer) icon, style-settings (sliders) icon and close. Left column: Off plus the embedded and external tracks. Right pane: a "Looking for subtitles..." spinner, then online results. Footer: "Find more subtitles" and "Load file".

**Theme tokens:** near-black background, translucent dark panels with 24 px radius, accent orange (~#F26A1B), white text, muted grey section labels in small caps with letter spacing.

## 2. Architecture

```
lib/
  app/            app shell, routing, theme, window setup
  core/
    player/       PlayerService (wraps media_kit Player + NativePlayer props)
    storage/      Drift DB, settings repo
    platform/     PiP, cast, file association, SMTC / MPRIS / Now Playing
    utils/
  features/
    playback/     controls, seek bar, volume, overlay auto-hide, gestures
    speed_sleep/  speed list, sleep timer logic, popover
    subtitles/    track list, load file, delay, style, online search
    translate/    subtitle translation
    library/      history, playlists, episodes, metadata
    pip/          PiP window mode
    cast/         Chromecast / DLNA
    download/     stream download manager
    settings/     preferences pages
    info/         media info dialog
test/ integration_test/ docs/ scripts/
```

Rules:
- Only `PlayerService` talks to libmpv. UI reads Riverpod providers backed by its streams.
- Every mpv property used is listed in `docs/mpv-properties.md`.
- Features are isolated folders with no cross-imports except through `core`.

## 3. Phases and tasks

### Phase 0: Setup (2–3 days)
- [x] 0.1 Create the GitHub repo `kyndrel` with the chosen licence, README, `.gitignore`, issue and PR templates.
- [x] 0.2 `flutter create` with Windows/Linux/macOS enabled, then add dependencies.
- [x] 0.3 Add `CLAUDE.md` (see section 7), lint rules (`very_good_analysis` or `flutter_lints`), and `analysis_options.yaml`.
- [x] 0.4 CI (GitHub Actions): analyze, test, and Windows build artifact on every push.
- [ ] 0.5 Spike: play a local file via media_kit with a bare Scaffold. Confirm hardware decoding.
  - Playback verified on Linux (Xvfb, software decode, see `docs/phase-0-spike.md`). **Still open:** confirm `hwdec-current` on a Windows machine with a GPU.
- [x] 0.6 Theme tokens and font loaded, with a golden test of the colour set.

### Phase 1: Core player (2–3 weeks)
- [x] 1.1 `PlayerService`: open file/URL, play, pause, seek, position/duration/buffering/state streams.
- [x] 1.2 Frameless window: custom title bar with drag area, minimize/maximize/close, double-click to maximize.
- [x] 1.3 Top bar: back, title, year, quality badge (derived from video height: 480P, 720P, 1080P, 4K), info icon.
- [x] 1.4 Seek bar: progress, buffered segment, hover time tooltip, drag-to-seek with debounce, elapsed/total labels, toggle between total and remaining time.
- [x] 1.5 Transport: ±10 s buttons, play/pause with animated icon, and configurable skip length.
- [x] 1.6 Volume: set `volume-max` to 400 through `NativePlayer.setProperty('volume-max', '400')`, then `setVolume` from 0 to 400. Add the slider, mute toggle, percentage label, and persist the value. Add `af=alimiter` (or `acompressor`) when volume exceeds 100 to reduce clipping, with a setting to turn it off.
- [x] 1.7 Fullscreen toggle (F, double-click on video) and exit-fullscreen icon.
- [x] 1.8 Controls overlay: auto-hide after 3 s of no mouse movement, hide the cursor in fullscreen, and keep controls visible while a popover is open.
- [x] 1.9 Keyboard shortcuts: Space, ←/→ (seek), ↑/↓ (volume), M, F, Esc, `[`/`]` (speed), S (subtitles), and a rebinding screen later.
- [x] 1.10 Mouse and touch gestures: click to play/pause, scroll to change volume, drag to seek on touch.
- [x] 1.11 Open flows: file picker, drag-and-drop, command-line argument, "Open with" file association, paste URL.
- [x] 1.12 Resume position: store on pause or exit and offer to resume on reopen.
- [x] 1.13 Error and loading states: spinner, "can't play this file" with the mpv log excerpt.
- **Exit criteria:** plays MP4, MKV, AVI, WebM, HLS and local 4K HEVC smoothly. All Phase 1 controls match the screenshots.
  - Status: MP4, MKV, AVI, WebM, HLS and HEVC open, play and seek in the real-libmpv engine tests (`flutter test -t engine --run-skipped`, generated by `scripts/make_test_media.sh`). **Still open:** 4K HEVC smoothness and hardware decoding need a manual check on a GPU machine (same as 0.5).
  - Notes: 1.9's rebinding screen is deferred to the settings page (5.1). Translate, PiP, cast and download buttons are in place but disabled until 4.1–4.4.

### Phase 2: Speed, sleep, subtitles and audio (2–3 weeks)
- [x] 2.1 Speed popover: set mpv `speed`, highlight the active option, and show `Normal DEFAULT` for 1.0. The bottom-right button shows the current rate and the popover opens above it.
- [x] 2.2 Pitch correction on (mpv `audio-pitch-correction=yes`), plus an optional custom speed field.
- [x] 2.3 Sleep timer service: fixed durations, "End of episode" (pause when playback completes) and "End of next episode" (counter across the playlist). Show remaining time on the button, a gentle volume fade-out for the last 30 s, and cancel/reset on selecting again.
- [x] 2.4 Subtitle panel UI (two columns, header icons, footer buttons).
- [x] 2.5 Subtitle tracks: list embedded and external tracks and select one (`sid`). "Off" sets `sid=no`.
- [x] 2.6 Load external subtitle file (`sub-add`), plus auto-load files with the same name next to the video.
- [x] 2.7 Sync offset (`sub-delay`) with ± buttons and a numeric field. Also add a secondary subtitle track (`secondary-sid`) for dual subtitles.
- [x] 2.8 Style settings: font, size, colour, outline, background box, position (`sub-pos`), and a live preview. Persist per user.
- [x] 2.9 Online search: OpenSubtitles API client (search by hash and by title/year/episode), result list with language, rating, download count, one-click download and apply, with cache and rate-limit handling. Store the API key in settings.
- [x] 2.10 Image-based subtitles (PGS, VobSub) display check.
- [x] 2.11 Audio tracks: list, select (`aid`), audio delay (`audio-delay`), and show language names (map ISO codes to full names).
- [x] 2.12 Video options: aspect ratio / fit (`video-aspect-override`, `panscan`) from the fit icon: Fit, Fill, Stretch, 16:9, 4:3, Original. Add zoom and rotate.
- **Exit criteria:** all panels in the screenshots work end to end, including online subtitle download.
  - Status: all panels work end to end against real libmpv (engine tests and a driven Linux build). Online search/download is covered by tests against a mocked OpenSubtitles API; **still open:** one live check with a real API key (none available in this environment).
  - Notes: audio tracks and audio delay (2.11) live in the same panel ("Subtitles & audio"). Fit/Fill/Stretch/Original are applied to the Flutter video texture (media_kit sizes the texture to the video, so mpv's `panscan` has no visible effect); 16:9/4:3 use `video-aspect-override`.

### Phase 3: Library and media intelligence (3–4 weeks)
- [x] 3.1 Playlist: queue, next/previous, shuffle, repeat, drag to reorder, and open a whole folder.
- [x] 3.2 Episode detection: parse filenames (`S01E02`, `1x02`) to group episodes. This powers "End of next episode" and auto-play of the next episode.
- [x] 3.3 History and continue-watching list with thumbnails and progress.
- [x] 3.4 Metadata: TMDB lookup for title, year, poster and episode names, with local cache and a manual override.
- [x] 3.5 Media info dialog (the "i" icon): container, codecs, bitrate, resolution, HDR, audio channels, file size, and a copy button.
- [x] 3.6 Chapters: markers on the seek bar and next/previous chapter.
- [x] 3.7 Seek-bar thumbnails: generate preview frames with a second headless mpv or FFmpeg and cache them.
- [x] 3.8 Screenshot: mpv `screenshot` command to a configured folder, with a toast.
- [x] 3.9 A-B loop and frame step.

### Phase 4: Advanced features (4–6 weeks)
- [x] 4.1 **Picture-in-picture:** small frameless always-on-top window with aspect-locked resize, a minimal control set, and double-click to restore. Same player instance, so no restart.
- [x] 4.2 **Subtitle translation (the translate icon):** take the active subtitle track, translate cue batches through a configurable provider (DeepL, Google, or an LLM API), cache by file hash and language, show as a secondary track, and handle failures gracefully.
- [x] 4.3 **Download button:** for network sources, a download manager with progress, pause/resume and a queue. Use HTTP range requests, and `yt-dlp` as an optional plugin for supported sites. Respect DRM and site terms by only offering it for sources the user is allowed to save.
- [x] 4.4 **Cast:** discover Chromecast and DLNA devices, serve the file over a local HTTP server, transcode when the codec is unsupported (FFmpeg), and sync play/pause/seek/volume. Do this last, as it is the hardest feature.
- [x] 4.5 Network streams: HLS, DASH, RTSP, SMB/WebDAV sources.
- [x] 4.6 Video quality: shader presets (e.g. upscaling), deband, HDR to SDR tone mapping, and a hardware-decoding selector.
- [x] 4.7 Equalizer and audio normalization (`loudnorm`, `dynaudnorm`).
- [x] 4.8 OS integration: media keys, Windows SMTC, Linux MPRIS, macOS Now Playing.
- [x] 4.9 Plugin or script hook (mpv Lua/JS scripts) as an optional power-user feature.

### Phase 5: Polish, QA and release (2–3 weeks)
- [x] 5.1 Settings page: playback, subtitles, audio, shortcuts, appearance, language, advanced (mpv.conf passthrough).
- [x] 5.2 Localisation: English and Arabic with RTL layout tests.
- [x] 5.3 Accessibility: keyboard focus order, screen-reader labels, and contrast checks.
- [ ] 5.4 Performance: cold start time, memory over a 3-hour film, CPU in 4K, no frame drops while the overlay animates.
- [ ] 5.5 Test matrix: HDR, 4K HEVC/AV1, 10-bit, VFR, broken MKVs, multi-audio files, image subtitles, huge subtitle files, network drops mid-stream.
- [ ] 5.6 Packaging: Windows installer (MSIX or Inno Setup), macOS signed DMG, Linux AppImage/deb, with auto-update.
- [ ] 5.7 Crash and log reporting (opt-in), a user-facing log viewer, and docs/README with screenshots.
- [ ] 5.8 Licence audit for bundled libmpv/FFmpeg builds and an `ATTRIBUTION.md`.
- [ ] 5.9 v1.0 release notes and tagged GitHub release.

## 4. Testing strategy
- **Unit:** sleep timer logic, subtitle parsing/offset, filename episode parser, volume mapping (0–400), time formatting.
- **Widget and golden:** seek bar, volume slider, speed popover, subtitle panel.
- **Integration:** open a sample file, seek, change speed, load subtitles, toggle PiP and fullscreen.
- **Manual device matrix:** Windows 10/11 (Intel, AMD, NVIDIA), one macOS, one Linux distro.
- Keep a small `test_media/` set of short, licence-free clips with tricky properties.

## 5. Risks

| Risk | Mitigation |
|---|---|
| Boosting to 400% clips or distorts audio | Limiter filter above 100%, a clear visual boost zone, and a warning on first use |
| Flutter video texture issues on some GPUs | Test early (task 0.5), keep the Qt fallback |
| OpenSubtitles API limits | Cache, rate limit, optional user API key |
| Casting complexity | Last in the schedule, shippable as a beta feature |
| Licensing (GPL vs LGPL) | Decide in Phase 0 and record it in the README |
| Download feature misuse | Only offer it for user-owned or openly licensed sources |

## 6. Rough timeline
Phase 0: 0.5 week, Phase 1: 3, Phase 2: 3, Phase 3: 4, Phase 4: 6, Phase 5: 3. About 19–20 weeks for one developer (less with parallel work). A usable v0.1 (Phases 0–2) is reachable in about 6 weeks.

## 7. Working with Claude Code

Put this in `CLAUDE.md` at the repo root:

```md
# Kyndrel
Flutter video player on libmpv via media_kit. Dark UI, orange accent (#F26A1B).
- Only core/player/PlayerService touches libmpv. UI uses Riverpod providers.
- Max volume is 400 (volume-max=400). Slider range 0..400.
- Follow PLAN.md; do tasks in order and tick the checkbox when done.
- Before finishing a task: `flutter analyze` and `flutter test` must pass.
- Keep commits small, one task per commit, message format: `feat(subtitles): load external file (2.6)`.
```

Suggested workflow:
1. Ask Claude Code to do one phase task at a time ("Do task 1.6 from PLAN.md").
2. Use plan mode for the larger tasks (2.9, 4.2, 4.4) before any code is written.
3. Add a custom slash command `/next-task` that reads PLAN.md, picks the first unchecked task, implements it, runs the checks and ticks the box.
4. Use a hook that runs `flutter analyze` after every edit.
5. Review each phase in a PR before merging.

First prompt to paste into Claude Code:

> Read PLAN.md and CLAUDE.md. Complete Phase 0 fully: create the Flutter project, dependencies, CI, theme tokens and the media_kit playback spike. Stop after Phase 0 and summarise what you did.

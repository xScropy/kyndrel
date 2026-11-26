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
- [x] 5.4 Performance: cold start time, memory over a 3-hour film, CPU in 4K, no frame drops while the overlay animates.
- [x] 5.5 Test matrix: HDR, 4K HEVC/AV1, 10-bit, VFR, broken MKVs, multi-audio files, image subtitles, huge subtitle files, network drops mid-stream.
- [x] 5.6 Packaging: Windows installer (MSIX or Inno Setup), macOS signed DMG, Linux AppImage/deb, with auto-update.
- [x] 5.7 Crash and log reporting (opt-in), a user-facing log viewer, and docs/README with screenshots.
- [x] 5.8 Licence audit for bundled libmpv/FFmpeg builds and an `ATTRIBUTION.md`.
- [x] 5.9 v1.0 release notes and tagged GitHub release.

### Phase 6: Android (plan: brightness/volume swipes, scene preview, APKs)
Decisions: brightness changes the player window only; volume swipes move the
phone's media volume, then Kyndrel's boost to 200 %; the seek bar shows a big
preview frame while dragging; releases are signed APKs on GitHub.
- [x] 6.1 Android project, desktop-only start-up split off, a `WindowService` for phones (immersive full screen, orientation); APK builds in CI.
- [x] 6.2 Opening media: "Open with"/share intents (content:// URIs), file picker, "Videos on this phone" from MediaStore.
- [x] 6.3 Touch gestures: left swipe brightness, right swipe volume then boost, horizontal seek, double-tap ±10 s (adds up), pinch zoom, long-press 2×, lock; level OSD; Settings › Gestures.
- [x] 6.4 Scene preview while seeking: big frame above the thumb on touch drags and during swipe-seek, with time and chapter; Android frame source if mpv's image output is missing.
- [x] 6.5 Phone layout: fewer buttons plus a "more" sheet, panels as bottom sheets, 48 dp targets, cutouts, rotate/lock orientation, keep screen on.
- [x] 6.6 Android integration: media notification and session, background audio, audio focus, pause on unplug, native PiP, multicast lock for DLNA, hide features needing ffmpeg/yt-dlp.
- [x] 6.7 Performance and battery: mediacodec decoding, less work when hidden.
- [x] 6.8 Tests and CI: gesture tests with fake platform services, phone goldens, emulator smoke test.
- [x] 6.9 Release: signed per-ABI APKs on GitHub releases, update check for APKs, licence audit, 1.1.0 notes.

### Phase 7: Library, music and scrubbing (1.2, Android + Windows/macOS)
- [x] 7.1 Subtitles that don't appear: reproduce with real libmpv (embedded/external/image tracks, during load, after file change, secondary track, visibility, hidden styles), fix, and report failures on screen instead of silently.
- [x] 7.2 Storyboard: frames for the whole video prepared in advance (one-pass mpv on desktop, MediaMetadataRetriever on Android), shown instantly while dragging, refined to the exact frame when the finger rests.
- [x] 7.3 Media index: Drift `LibraryItems`, MediaStore videos and audio on Android, Videos/Music folders plus added ones on desktop (macOS bookmarks), details and thumbnails probed in the background.
- [x] 7.4 Video library like MX Player: folders and all videos, list/grid, thumbnails with duration and progress, resolution, size, date, NEW, sort, search, details sheet.
- [x] 7.5 Music library, separate from videos: songs, albums, artists, folders, shuffle, mini player.
- [x] 7.6 Music player: spinning disc with the cover art, tags, live orange waves following the loudness (mpv astats), less-motion setting.
- [x] 7.7 Release 1.2.0.

### Phase 8: Light and smooth: YouTube-style scrubbing, MX-style library and browser (1.3)
Decisions: keep Flutter + libmpv; cut RAM/CPU by sharing one hidden mpv for all
frame work, smaller demuxer caches for local files, no sync IO or polling on the
UI isolate, and repaint-only scrubbing. Storyboards become YouTube-style sprite
sheets in levels (L0 whole video, tiny; L1/L2 denser), made coarse-to-fine and
prepared in advance for library videos. A Rust FFmpeg frame helper is built only
if the storyboard benchmark shows mpv is >2× slower or >40 MB heavier.
Budget: Android idle library ≤ 110 MB PSS and 0 % CPU, 1080p playback ≤ 220 MB,
desktop idle ≤ 150 MB RSS, no frame over 16 ms while scrolling or scrubbing.
- [x] 8.0 Preview bugs: cache keys ignore file size/mtime, `previews/` cache has no limit, storyboard cancel race, Android marks partial storyboards complete, sync file IO on the UI isolate.
  - Also fixed: the desktop storyboard counted files in a scratch folder it emptied, so every frame after the first waited out the 3 s timeout. Frames are now found by name.
  - Folder listings in render loops and cache trims are async. The 500 ms storyboard poll stays until 8.2 replaces it with a progress stream.
- [x] 8.1 Lean engine: one shared, lazily started, auto-disposed frame engine for storyboard, exact frames and probing (≤ 2 libmpv instances); lean decode options; smaller demuxer cache for local files; image-cache cap and memory-pressure handling; no idle timers; deferred feature imports.
  - `FrameEngine` (`core/player/frame_engine.dart`): jobs by priority (exact frame > storyboard > library), a storyboard hands over between frames and resumes, mpv closes after 30 s idle, on memory pressure and when the window is hidden. Seek-bar frames seek in the open file instead of reloading it. Library thumbnails no longer get dropped by hover requests.
  - History and resume saving tick only while playing.
  - Deferred imports dropped: on desktop and Android AOT builds all code is in one snapshot, so they save no memory.
- [x] 8.2 Storyboard v2: sprite sheets with levels L0/L1/L2 and `spec.json`, bisection order with priority near the drag/playhead, sheet packing in an isolate (desktop) or Kotlin (Android), progress stream instead of polling, benchmark script.
  - Levels: L0 = 100 frames at 96 px in one 10×10 sheet (the whole video), L1 = a frame every 2 s (≤ 300) at 160 px in 5×5 sheets, L2 = 320 px on phones. Seek bar shows the finest level that has the frame, else the nearest coarse one.
  - Benchmark (`scripts/bench_storyboard.sh`, 20-minute 1080p H.264, this container): coarse level in 5.7 s, all 400 frames in 19.8 s (~50 ms a frame), 940 KB on disk. The Rust helper is not built: a keyframe decode and scale alone take much of those 50 ms, so it couldn't be 2× faster.
  - Android keeps its native frame loop (no Kotlin change); Dart packs the sheets at each level's end. The tiles folder is listed once a second while the native loop runs, since it reports nothing until the end.
- [x] 8.3 Smooth preview: LRU of decoded sheets, tile painted with `drawImageRect`, no `setState` per pointer move, L0 → L1/L2 → exact frame, chapter title and haptic tick.
  - The seek bar keeps hover, drag and frame in `ValueNotifier`s: a pointer move repaints the bar and bubble only (a test checks 30 moves cause no rebuild). Sheets around the finger are decoded ahead; the exact frame fades in over the cell (150 ms); phones tick on chapter changes.
- [x] 8.4 Library previews made in advance (L0 sheet per video, lowest priority, "only while charging" setting).
  - `LibraryPreviewsController`: after 10 s of quiet and while nothing plays, the newest library video without one gets its coarse level (one 10×10 sheet), through its own storyboard source at the frame engine's lowest priority, so it never cancels the playing file's storyboard. Playback cancels it at once. Settings › Library: Automatic (always on desktop, only while charging on phones) / Always / Only while charging / Off, plus the preview cache size. Never in battery saver (battery_plus).
- [x] 8.5 Library data: folders (hidden, pinned, private, sort), bookmarks, saved playlists, per-file settings; paged SQL queries; live refresh (`Directory.watch`, MediaStore observer); `.nomedia`.
  - Schema 4: `LibraryFolders`, `Bookmarks`, `SavedPlaylists`/`SavedPlaylistItems`, `FileSettings`, `Replays`, `IntroMarks`; `watched` and `hasSubtitles` on `LibraryItems`. `LibraryRepository` groups folders and sorts/filters items in SQL (name order stays natural, done after the query). Full lists rather than pages: 10 000 rows are a few MB (checked in 8.12).
  - Desktop scan runs in an isolate, skips `.nomedia` folders and notices subtitle files next to videos. `LibraryWatcher` watches the library folders (not recursively: Linux can't) and rescans 2 s after a change; any platform rescans when the app comes back after 10 minutes. Android MediaStore change events would need native code: not done.
- [x] 8.6 Library like MX Player: fast-scroller with bubble, hover/slide previews on cards, multi-select with file actions, folder actions, views and filters, badges, kept scroll position, playlists.
  - Folders · All videos · Recently added · Playlists, a continue-watching row, list/grid/compact with three grid sizes, ascending/descending, filters (unwatched, HD, subtitles), quality/CC/NEW/last-played badges, scroll position kept per view, each folder remembering its order and layout.
  - Fast-scroller with a letter/month/size bubble (fixed row heights, so a jump costs nothing); hover or a sideways finger slide on a thumbnail flips through the coarse storyboard.
  - Long-press selects (tap adds), select all, play, queue, add to a playlist, mark watched/unwatched, details; on desktop also rename and move (subtitle files follow) and move to the trash (gio / freedesktop trash, Finder, Recycle Bin).
  - Folder sheet: play all, shuffle, pin, hide (and "show hidden"), private behind a PIN (a hash in settings: a privacy curtain, not encryption); private folders and incognito never reach history, decided when the file opens.
  - Saved playlists (create, add, reorder, rename, delete) and two smart ones (unwatched, added this month).
  - Not done: rename/move/delete and share on Android (MediaStore changes need a native confirmation flow); device-auth unlock.
- [x] 8.7 Browse mode: file tree with breadcrumbs (storage roots, SD/USB, drives) and network servers (SMB, FTP/SFTP, WebDAV, DLNA).
  - A Browse section (the app passes it to the library shell, so features stay apart): storage roots (home, library folders, drives, `/Volumes`, `/media`, `/mnt`, Android storage), folders and playable files, breadcrumbs, search in the folder, play all, shuffle; a file plays on through its folder.
  - Network: WebDAV (client moved to `core/net`), FTP (a small passive-mode client, tested against a socket server; mpv plays `ftp://`), DLNA/UPnP media servers found by SSDP and browsed with ContentDirectory. Servers are saved without passwords; a password is asked once per session and kept in memory.
  - SMB and SFTP are saved and opened by address only: listing them would need protocol libraries Kyndrel doesn't have.
- [ ] 8.8 Player extras from MX/mpvKt/Next Player/VLC/IINA/Haruna/SMPlayer/Just Player: bookmarks, per-file settings, quick decoder switch, long-press speed slide, custom buttons and gestures, video adjustments, stats overlay, subtitle list, passthrough, frame-rate matching, clip export, jump to time, incognito, AMOLED theme.
- [ ] 8.9 Skip intro/credits from shared storyboard hashes across episodes, chapters, or a saved mark.
- [ ] 8.10 Local "most replayed" heatmap on the seek bar.
- [ ] 8.11 Reliability: cancellation tokens, native-call timeouts, fault-injection tests, parser fuzzing.
- [ ] 8.12 Performance harness (`scripts/measure_perf.sh`) and budget checks in CI; large-library and scrub rebuild tests.
- [ ] 8.13 Release 1.3.0.

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

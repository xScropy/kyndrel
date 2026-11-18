# Changelog

All notable changes to Kyndrel. The release workflow copies a version's
section into its GitHub release.

## [1.0.0] - 2026-11-18

The first release: a desktop video player for Windows, macOS and Linux,
built on libmpv with a dark, orange-accented interface.

### Playback
- Plays what mpv plays (MP4, MKV, AVI, WebM, HEVC, AV1, 10-bit, HDR10,
  VFR, HLS, DASH) with hardware decoding when available.
- Frameless window with its own title bar; full screen; picture-in-picture
  in the same window.
- Seek bar with buffered range, hover time, preview thumbnails, chapter
  marks and A-B loop; frame stepping.
- Volume to 400 % with a limiter above 100 %; speed 0.1–4× with pitch
  correction; sleep timer (duration, end of episode, end of next episode)
  with fade-out.
- Fit, fill, stretch, aspect overrides, zoom and rotate.
- Picture quality presets (scaling) with an optional sharpen shader, a
  hardware-decoder choice and HDR tone mapping; audio normalisation and
  a 10-band equaliser.
- Screenshots to a folder of your choice.

### Subtitles and audio
- Embedded, image (PGS/VobSub) and external tracks; matching files next to
  the video load automatically.
- Sync offset, dual subtitles, styling with a live preview.
- OpenSubtitles search and download.
- Translation of the active track into a second line via Claude, DeepL or
  Google.
- Audio track selection and delay.

### Library
- Resume where you left off; history with thumbnails; continue watching.
- Queue with shuffle, repeat and reordering; folders; the rest of a season
  queues itself.
- TMDB titles, posters and episode names (optional key), with manual
  correction.

### Network and devices
- Network streams with logins and custom headers; WebDAV browsing.
- Downloads with resume, and yt-dlp when it's installed.
- Casting to Chromecast and DLNA (beta: tested against emulated devices
  only).
- Media keys and the OS media controls (MPRIS on Linux, SMTC on Windows,
  Now Playing on macOS).
- Lua and JavaScript mpv scripts (off by default).

### App
- Settings with every shortcut rebindable and an mpv options field.
- English and Arabic, with a right-to-left layout.
- Keyboard focus order, screen-reader labels and WCAG AA text contrast.
- Installers: Windows setup (with "Open with" and Default apps), macOS
  DMG, Linux .deb and AppImage; update check with a one-click update on
  Windows.
- App log with a viewer; after a crash, an opt-in offer to open a
  pre-filled GitHub issue.

### Known limitations
- The macOS DMG and the Windows installer are unsigned unless signing
  secrets are set up: macOS asks you to right-click › Open the first time,
  and Windows SmartScreen warns.
- Casting has not been tried on real Chromecast or DLNA devices.
- Some dialogs (media info, cast, download, effects, settings details)
  are still English in the Arabic UI.
- Memory use over a 3-hour film has been measured for 25 minutes only;
  see docs/performance.md.

### Licences
Kyndrel is GPL-3.0. Bundled libmpv/FFmpeg builds and every dependency are
listed in ATTRIBUTION.md, with links to their source.

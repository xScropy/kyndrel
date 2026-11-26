# Changelog

All notable changes to Kyndrel. The release workflow copies a version's
section into its GitHub release.

## [1.3.0] - 2026-11-26

Lighter and smoother: scrubbing like YouTube, a library like MX Player, a
Browse section for folders and network servers, and many player extras.

### Scrubbing
- Storyboards now come in levels like YouTube's: a small sheet covering
  the whole video first, then finer frames, made coarse to fine so every
  part of the timeline has a frame within seconds; frames near your finger
  come first.
- Library videos get their coarse storyboard while Kyndrel is idle
  (Settings > Library: always, only while charging, or off), so a video
  opened from the library scrubs at once.
- The seek bar only repaints while you drag (no rebuilds), sheets around
  your finger are decoded ahead, and the exact frame fades in when you
  rest.

### Library
- Folders, All videos, Recently added and Playlists; a continue-watching
  row; list, grid (three sizes) or compact; filters (unwatched, HD,
  subtitles); ascending/descending; each folder remembers its order and
  layout.
- A fast-scroller with a letter, month or size bubble; thumbnails flip
  through the video's scenes when you hover or slide a finger across them.
- Long-press to select: play, queue, add to a playlist, mark watched or
  unwatched; on computers also rename, move, and move to the trash.
- Folders can be pinned, hidden, or made private behind a PIN.
- Saved playlists, plus "Unwatched" and "Added this month".
- The library updates itself when files are added or removed (computers),
  or when you come back to the app after a while.

### Browse
- A new section: your device's folders and drives, and network servers
  (WebDAV, FTP, media servers found on the network; SMB and SFTP open by
  address).

### Player
- Bookmarks (B, Ctrl+B), jump to time (Ctrl+G), playback statistics
  (Shift+I), HW / HW+ / SW decoding (H, or the badge at the top).
- Each file remembers its audio and subtitle tracks, speed, delays, fit
  and zoom. Incognito leaves no history, resume points or file settings.
- "Skip intro" and "Next episode": from chapters, from a mark you set with
  Shift+M, or found by comparing episodes of a season.
- A "most replayed" curve over the seek bar from what you rewatch (kept
  on your device).
- Picture adjustments, audio passthrough, external audio tracks, ZIP
  subtitles, a list of subtitle lines (Ctrl+T), your own quick commands
  (Ctrl+K), mouse buttons, saving the A-B loop as a clip or GIF (with
  ffmpeg), hold-for-2x with a slide to change speed, a swipe for the next
  file on phones, and a pure black theme.

### Lighter
- One hidden player for storyboards, previews and the library instead of
  three, started only when needed and closed after 30 s idle.
- Smaller read-ahead buffers for local files; a cap on decoded images;
  nothing ticks while idle.
- A big library's first scan no longer slows down as it goes.

### Fixes
- The desktop storyboard waited 3 s for every frame after the first.
- A file replaced under the same name showed the old one's thumbnails.
- Storyboards with missing frames were marked finished on Android.
- A file watched in incognito could be added to history when the next
  one opened.

### Known limitations
- Rename, move, delete and share are not available for Android's media
  files yet.
- Display frame-rate matching is not done.

## [1.2.0] - 2026-11-20

A library and a music player, and a seek bar that shows the scene under
your finger, on Android, Windows and macOS.

### Library
- The start screen has three sections: Home (open, continue watching,
  recent), Videos and Music. A bar along the bottom on phones, a rail on
  the side on computers.
- Videos, like a phone video player: folders with thumbnails, then the
  videos in a folder (or all of them), each with its thumbnail, length,
  how much you've watched, resolution, size, date and NEW. List or grid,
  sort by date, name, size or length, search. Tap to play with the rest
  of the folder queued; long-press for the details.
- Music, separate from the videos: songs, albums (with covers), artists
  and folders, play all, shuffle and search.
- Android reads the phone's videos and music; Windows and macOS look in
  your Videos (Movies) and Music folders, plus folders you add (they stay
  readable on macOS after a restart).

### Music player
- Songs play on a turning record with the cover art as its label, with
  the title, artist and album, and orange waves that move with the music.
- Shrink it to a mini player and keep browsing while it plays.
- The notification and lock screen show the song and its cover.
- Settings > Audio > Music: waves on or off, and less motion.

### Seeking
- Like YouTube: frames for the whole video are prepared in the
  background, so dragging the seek bar or swiping shows the scene at
  once; resting shows the exact frame.

### Fixes
- Android: text subtitles (SRT, ASS, VTT) were chosen but never shown,
  because the subtitle renderer had no fonts. Kyndrel's own fonts are used
  now, Arabic included.
- Choosing the track that was the second subtitle line now moves it to the
  main line instead of doing nothing; choosing a track turns subtitles
  back on; a track that can't be shown says so.
- Android: subtitle files can be loaded from the phone.

### Known limitations
- Library details on desktop are read in the background: a large music
  collection takes a while to get its covers the first time.
- Tested on an emulator in CI; the real-phone checklist is in
  docs/android.md.

## [1.1.0] - 2026-11-18

Kyndrel for Android: the same player on phones and tablets, with a touch
layout and gestures. See docs/android.md.

### Android
- APKs for arm64, 32-bit ARM and x86_64 phones, plus a universal one
  (Android 7.0+). The update check offers the right one.
- Swipe the left side for brightness (Kyndrel only) and the right side for
  volume: the phone's volume first, then Kyndrel's boost up to 200 %.
- Swipe sideways to seek with a large preview of the scene, its time and
  chapter. Dragging the seek bar shows the same preview above your finger.
  Previews are prepared in the background after a file opens.
- Double-tap the sides to skip (taps add up), double-tap the middle to
  pause, pinch to zoom, hold for 2× speed, and lock the screen against
  pocket touches. Each gesture can be turned off in Settings › Gestures.
- Phone layout: the main controls in the bar and the rest in a "…" sheet,
  panels sized for the screen, 48 dp buttons, cutout-safe, immersive full
  screen while playing, turned to the video's shape with a rotate button.
- "Open with" and Share from other apps; "On this phone" lists the
  phone's videos by folder and queues the rest of the folder.
- The media notification and lock screen controls; headset and Bluetooth
  buttons; pause for calls and resume after; pause when headphones are
  unplugged.
- Optional playback in the background (audio only), and
  picture-in-picture, including on Home.
- MediaCodec hardware decoding.

### Everywhere
- Narrow windows get the phone layout, and Settings shows one section at
  a time.

### Known limitations
- Not on Android: transcoding for casting, translating subtitles inside
  the video, and site downloads (they need FFmpeg or yt-dlp).
- Subtitles next to a video load automatically only for "On this phone"
  files; load others from the subtitles panel.
- Tested on an emulator in CI; the real-phone checklist is in
  docs/android.md.

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

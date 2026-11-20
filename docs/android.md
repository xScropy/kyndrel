# Kyndrel on Android

Phase 6. The same app and player as on desktop. On a phone it uses a
touch layout, gestures and the phone's own media controls.

## Install

Download an APK from [Releases](https://github.com/xScropy/kyndrel/releases):

| APK | For |
|---|---|
| `Kyndrel-<version>-android-arm64-v8a.apk` | Almost every phone from the last ten years |
| `Kyndrel-<version>-android-armeabi-v7a.apk` | Older 32-bit phones |
| `Kyndrel-<version>-android-x86_64.apk` | Emulators and some Chromebooks |
| `Kyndrel-<version>-android-universal.apk` | Any of these, if you're not sure (larger) |

Android asks once to allow installs from your browser. Kyndrel checks for
updates like the desktop versions do: "Update" opens the right APK, and
Android installs it over the old one. Your history and settings are kept.
Android 7.0 or newer is needed.

## Gestures

| Gesture | Does |
|---|---|
| Swipe up/down, left half | Brightness, for Kyndrel only. The system setting is untouched. |
| Swipe up/down, right half | Volume: the phone's media volume, then Kyndrel's boost up to 200 % |
| Swipe left/right | Seek, with a large preview of the scene, its time and chapter |
| Drag the seek bar | The same preview above your finger |
| Double-tap left/right third | Back/forward by the skip length. Tapping again adds more. |
| Double-tap the middle | Play/pause |
| Pinch | Zoom |
| Press and hold | 2× speed while held |
| Lock button | Ignores touches until you tap Unlock |

Each gesture can be turned off in Settings › Gestures. Swipes that start
at the screen edges are left to Android (back gesture, notification shade).

## Phone behaviour

- Full screen while a video plays, turned to the video's shape. The rotate
  button overrides that, and leaving the video restores the bars.
- The media notification and lock screen controls: −10 s, play/pause,
  +10 s, previous/next. Headset and Bluetooth buttons work too.
- Leaving the app pauses. With Settings › Gestures › "Keep playing in the
  background", the sound goes on; only the audio is decoded then.
- Going Home while a video plays opens picture-in-picture (can be turned
  off). PiP is also in the "…" sheet.
- Calls pause playback and it resumes afterwards. Another app playing stops
  Kyndrel. Unplugging headphones pauses.
- "On this phone" on the start screen lists the phone's videos by folder.
  "Open with" and Share from other apps work.

## Not on Android

- Features that need the `ffmpeg` or `yt-dlp` programs: transcoding for
  casting, translating subtitles that are inside the video, and
  site downloads. Subtitle files can still be translated, casting plays
  files the device supports, and plain links can be downloaded.
- Subtitles next to a video are found automatically only for files from
  "On this phone". For a file opened from elsewhere, load the subtitle
  from the subtitles panel, because Android doesn't let apps read the
  neighbouring files.

## Checklist on a real phone

CI builds the APKs and runs a smoke test on an emulator (open, play, swipe,
preview, subtitles). These need a person with a phone. Tick them per
release:

- [ ] Opens from Files and Photos/Gallery with "Open with", and from Share
- [ ] "On this phone" asks for access once, then lists folders and plays
- [ ] Brightness swipe; brightness is back to normal after leaving
- [ ] Volume swipe moves the phone's volume, then the boost past 100 %
- [ ] Swipe seek and seek-bar drag show the scene preview quickly
- [ ] Double-tap ±10 s (adds up), pinch zoom, hold for 2×
- [ ] Lock and unlock
- [ ] Rotate button; auto-rotation for portrait and landscape videos
- [ ] Notification and lock-screen controls; Bluetooth headset buttons
- [ ] Background audio on and off; screen off for 10 minutes
- [ ] PiP from Home and from the "…" sheet; its buttons
- [ ] A phone call pauses and resumes; unplugging headphones pauses
- [ ] Hardware decoding shown in the media info (MediaCodec) for H.264/HEVC
- [ ] Casting to a TV on the same Wi-Fi
- [ ] Arabic layout
- [ ] Text subtitles (SRT/ASS) draw on the video, including Arabic ones; a subtitle file loads from the phone
- [ ] The update check offers the right APK, and it installs over the old one

## Release key

Release APKs are signed in `.github/workflows/release.yml` from the
`ANDROID_KEYSTORE`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and
`ANDROID_KEY_PASSWORD` secrets. Make the key once and keep a backup:
phones refuse updates signed with a different key.

```sh
keytool -genkey -v -keystore kyndrel-release.jks -keyalg RSA -keysize 4096 \
  -validity 10000 -alias kyndrel
base64 -w0 kyndrel-release.jks   # paste as ANDROID_KEYSTORE
```

Local builds (`flutter run`, `flutter build apk`) use the debug key, or
`android/key.properties` if it exists (it is ignored by git).

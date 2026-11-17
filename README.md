# Kyndrel

A modern desktop-first video player built on **libmpv** (via
[media_kit](https://github.com/media-kit/media-kit)) with a dark,
orange-accented Flutter UI.

> Status: **Phase 0** (project setup and playback spike). See [PLAN.md](PLAN.md).

## Targets

Windows first, then Linux and macOS, then Android/iOS.

## Build

Requires Flutter 3.50 (stable).

```sh
flutter pub get
flutter run -d windows            # or -d linux / -d macos
flutter run -d windows -- <file>  # open a file on start
```

Linux needs libmpv and the usual desktop toolchain:

```sh
sudo apt install libmpv-dev mpv clang cmake ninja-build pkg-config libgtk-3-dev
```

## Checks

```sh
flutter analyze
flutter test
```

CI runs both on every push and builds a Windows artifact.

## Licence

Kyndrel is licensed under the **GNU GPL v3.0** (see [LICENSE](LICENSE)).

GPL-3.0 was chosen because it is compatible with both GPL and LGPL builds of
libmpv/FFmpeg, so the bundled engine build can be chosen freely. A licence
audit of the shipped binaries is planned for task 5.8 (`ATTRIBUTION.md`).

The bundled Inter font is under the SIL Open Font License 1.1
(`assets/fonts/OFL.txt`).

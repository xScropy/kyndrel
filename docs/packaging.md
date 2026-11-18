# Packaging and updates (task 5.6)

| Platform | Package | Script | Notes |
|---|---|---|---|
| Windows 10 1809+ | `Kyndrel-<v>-windows-x64-setup.exe` (Inno Setup) | `packaging/windows/kyndrel.iss` | Per-user install by default (no admin prompt), all-users on request. Registers "Open with" and Settings › Default apps for 28 video/audio/playlist types without taking over existing defaults. Start menu entry, optional desktop icon, uninstaller. |
| macOS 11+ | `Kyndrel-<v>-macos-universal.dmg` | `packaging/macos/make_dmg.sh` | Drag-to-Applications DMG. Signed with the hardened runtime and notarised when the signing secrets exist; otherwise unsigned (right-click › Open the first time). |
| Debian 12+, Ubuntu 23.04+ | `kyndrel_<v>_amd64.deb` | `packaging/linux/make_deb.sh` | Installs to `/opt/kyndrel`, `/usr/bin/kyndrel`, desktop entry and icons. Uses the system `libmpv2` and `libsqlite3-0`. |
| Other Linux | `Kyndrel-<v>-x86_64.AppImage` | `packaging/linux/make_appimage.sh` | Bundles libmpv, FFmpeg and SQLite (built on Ubuntu 24.04, so needs glibc ≥ 2.39). Ships a `libmpv.so` link to the bundled `libmpv.so.2`: media_kit dlopens `libmpv.so` first, and without it a system libmpv-dev would be loaded alongside the bundled copy (mpv aborts). |
| Android | `Kyndrel-<v>-android-{arm64-v8a,armeabi-v7a,x86_64,universal}.apk` | `android` job in `release.yml` | Signed with the release key from the `ANDROID_*` secrets (a tag build fails without them). See [android.md](android.md). |

Icons for every platform come from `scripts/make_icons.py`.

## Releasing
`.github/workflows/release.yml` builds all four packages:
- on a `vX.Y.Z` tag: checks that the tag, `pubspec.yaml` and
  `lib/core/app_info.dart` agree, then attaches the packages to a **draft**
  GitHub release with that version's section of `CHANGELOG.md`. A
  maintainer reviews and publishes it, by hand or with the manual
  **Publish release** workflow (`publish-release.yml`), which first checks
  that all eight packages (including the four APKs) are attached.
- on any push that touches `packaging/` or the workflow, and on manual
  runs: packages only, as workflow artifacts.

The Linux job starts the AppImage under Xvfb to check it launches.

## Release checklist
1. Version in `pubspec.yaml` and `lib/core/app_info.dart` (a test keeps
   them equal), and a `## [X.Y.Z]` section in `CHANGELOG.md`.
2. `python3 scripts/licence_audit.py` if dependencies changed.
3. CI green on the commit: tests, engine tests, Windows/macOS builds,
   packaging.
4. Push the tag: `git tag -a vX.Y.Z -m "Kyndrel X.Y.Z" && git push origin vX.Y.Z`.
5. The Release workflow attaches the four packages to a **draft**
   release. Before publishing, install each one: Windows (Open with, Default
   apps, uninstall), macOS (first launch, Open with), the `.deb` on Ubuntu,
   and the AppImage on another distribution. Then publish: running copies
   offer the update from then on.

## Updates
With Settings › Advanced › *Check for updates* on (the default), Kyndrel
asks the GitHub API for the latest published release 5 s after start
(drafts and pre-releases are ignored). If it is newer than `appVersion`, a
banner offers it:

- **Windows: "Install and restart".** Downloads the setup, runs it with
  `/SILENT /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS` and closes Kyndrel
  (resume points are saved first). The installer replaces the files and
  starts the new version.
- **macOS and Linux: "Download".** Opens this platform's package (DMG,
  `.deb`, or the AppImage when running from one) in the browser. Replacing
  an app bundle in place needs a signed updater framework (e.g. Sparkle);
  the `.deb` updates through the package manager.

Settings › About › *Check for updates* checks on demand and also reports
"up to date" or why the check failed. The only data sent is a request for
`api.github.com/repos/xScropy/kyndrel/releases/latest` with the user agent
`Kyndrel-update-check`.

## Verified here / not verified
- `.deb`: built, installed and started on Ubuntu with `libsqlite3-dev`
  removed (the bundled `lib/libsqlite3.so` link is enough), then removed.
- Inno Setup, DMG and AppImage: built by the Release workflow on GitHub's
  runners; installing on real Windows and macOS machines is still a
  manual check.
- Signing: no certificates are configured; Windows SmartScreen will warn
  about an unsigned installer until a code-signing certificate is added.

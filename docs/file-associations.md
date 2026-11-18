# "Open with" and file associations (task 1.11)

| Platform | How a file reaches Kyndrel | Registered by |
|---|---|---|
| Windows | Path as the first command-line argument (`kyndrel.exe "C:\film.mkv"`), parsed by `LaunchOptions` | The installer (`packaging/windows/kyndrel.iss`) registers the `Kyndrel.Media` ProgID, `OpenWithProgids` for each extension, `Applications\kyndrel.exe\SupportedTypes`, and Default-apps capabilities. A portable copy: right-click a file › Open with › Choose another app › browse to `kyndrel.exe`. |
| Linux | `%f` in `linux/kyndrel.desktop` (command-line argument) | The `.deb` installs the `.desktop` file (the AppImage embeds it; AppImageLauncher or `appimaged` integrates it); for a manual install copy it to `~/.local/share/applications/` and run `update-desktop-database`. |
| macOS | Apple Event → `AppDelegate.application(_:open:)` → `kyndrel/open_file` method channel → `PlayerPage` | `CFBundleDocumentTypes` in `macos/Runner/Info.plist` (video and audio, rank *Alternate*). |

Other ways to open media: the file picker (Ctrl+O, or the button on the
start screen), drag-and-drop onto the window, pasting a path or URL
(Ctrl+V, or the field on the start screen), and the right-click menu.

macOS sandbox note: files opened via the picker, drag-and-drop or "Open with"
are readable; subtitle files *next to* the video are only auto-loaded once
the app has access to that folder (planned with the folder/playlist work in
task 3.1).

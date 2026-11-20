import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Now Playing and remote commands (task 4.8).
  private var mediaSession: MediaSession?
  /// Library folders kept across restarts (task 7.3).
  private var folderBookmarks: FolderBookmarks?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Hands "Open with" files to Dart (see lib/app/player_page.dart).
    let channel = FlutterMethodChannel(
      name: "kyndrel/open_file",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    if let delegate = NSApp.delegate as? AppDelegate {
      delegate.openFileChannel = channel
      channel.setMethodCallHandler { call, result in
        if call.method == "pending" {
          result(delegate.pendingFiles)
          delegate.pendingFiles.removeAll()
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    mediaSession = MediaSession(messenger: flutterViewController.engine.binaryMessenger)
    folderBookmarks = FolderBookmarks(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

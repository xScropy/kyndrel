import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// Files from "Open with" / Finder before Flutter was ready.
  var pendingFiles: [String] = []

  /// Set by MainFlutterWindow once the engine exists.
  var openFileChannel: FlutterMethodChannel?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  // "Open with Kyndrel" and double-clicking an associated file (task 1.11).
  override func application(_ application: NSApplication, open urls: [URL]) {
    let paths = urls.map { $0.isFileURL ? $0.path : $0.absoluteString }
    guard let channel = openFileChannel, let first = paths.first else {
      pendingFiles.append(contentsOf: paths)
      return
    }
    channel.invokeMethod("open", arguments: first)
  }
}

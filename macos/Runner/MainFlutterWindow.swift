import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
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

    super.awakeFromNib()
  }
}

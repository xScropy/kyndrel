import Cocoa
import FlutterMacOS

/// Keeps access to library folders the user added (task 7.3). The app is
/// sandboxed: a folder chosen in the open panel is readable only until the
/// app quits, unless a security-scoped bookmark is saved and resolved on
/// the next start.
///
/// `kyndrel/bookmarks`:
/// - `create` {path} -> base64 bookmark data
/// - `resolve` {data} -> the folder's path (access stays open), or null
final class FolderBookmarks {
  private let channel: FlutterMethodChannel
  private var open: [URL] = []

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "kyndrel/bookmarks", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self, let args = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "create":
        guard let path = args["path"] as? String else { return result(nil) }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        do {
          let data = try url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil)
          result(data.base64EncodedString())
        } catch {
          result(FlutterError(code: "bookmark", message: error.localizedDescription, details: nil))
        }
      case "resolve":
        guard let text = args["data"] as? String,
              let data = Data(base64Encoded: text) else { return result(nil) }
        var stale = false
        guard let url = try? URL(
          resolvingBookmarkData: data,
          options: [.withSecurityScope],
          relativeTo: nil,
          bookmarkDataIsStale: &stale)
        else { return result(nil) }
        if url.startAccessingSecurityScopedResource() {
          self.open.append(url)
        }
        result(url.path)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  deinit {
    for url in open { url.stopAccessingSecurityScopedResource() }
  }
}

import Cocoa
import FlutterMacOS
import MediaPlayer

/// macOS Now Playing (Control Center, media keys, AirPods) for Kyndrel
/// (PLAN.md task 4.8). Dart sends state on "kyndrel/media_session";
/// commands go back as method calls ("play", "next", "seekTo"...).
final class MediaSession {
  private let channel: FlutterMethodChannel
  private let center = MPRemoteCommandCenter.shared()

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "kyndrel/media_session", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "update", let args = call.arguments as? [String: Any] {
        self?.update(args)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    bind(center.playCommand, "play")
    bind(center.pauseCommand, "pause")
    bind(center.togglePlayPauseCommand, "playPause")
    bind(center.stopCommand, "stop")
    bind(center.nextTrackCommand, "next")
    bind(center.previousTrackCommand, "previous")
    center.skipForwardCommand.preferredIntervals = [10]
    center.skipBackwardCommand.preferredIntervals = [10]
    center.skipForwardCommand.addTarget { [weak self] _ in
      self?.channel.invokeMethod("seekBy", arguments: 10000)
      return .success
    }
    center.skipBackwardCommand.addTarget { [weak self] _ in
      self?.channel.invokeMethod("seekBy", arguments: -10000)
      return .success
    }
    center.changePlaybackPositionCommand.addTarget { [weak self] event in
      guard let e = event as? MPChangePlaybackPositionCommandEvent else {
        return .commandFailed
      }
      self?.channel.invokeMethod("seekTo", arguments: Int(e.positionTime * 1000))
      return .success
    }
  }

  private func bind(_ command: MPRemoteCommand, _ method: String) {
    command.addTarget { [weak self] _ in
      self?.channel.invokeMethod(method, arguments: nil)
      return .success
    }
  }

  private func update(_ args: [String: Any]) {
    let info = MPNowPlayingInfoCenter.default()
    guard let title = args["title"] as? String, !title.isEmpty else {
      info.nowPlayingInfo = nil
      info.playbackState = .stopped
      return
    }
    let playing = args["playing"] as? Bool ?? false
    let position = Double(args["positionMs"] as? Int ?? 0) / 1000
    let duration = Double(args["durationMs"] as? Int ?? 0) / 1000
    var now: [String: Any] = [
      MPMediaItemPropertyTitle: title,
      MPMediaItemPropertyMediaType: MPMediaType.anyVideo.rawValue,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
      MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
    ]
    if let subtitle = args["subtitle"] as? String, !subtitle.isEmpty {
      now[MPMediaItemPropertyAlbumTitle] = subtitle
    }
    if duration > 0 {
      now[MPMediaItemPropertyPlaybackDuration] = duration
    }
    info.nowPlayingInfo = now
    info.playbackState = playing ? .playing : .paused
    center.nextTrackCommand.isEnabled = args["canNext"] as? Bool ?? false
    center.previousTrackCommand.isEnabled = args["canPrevious"] as? Bool ?? false
  }
}

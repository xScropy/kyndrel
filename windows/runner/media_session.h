#ifndef RUNNER_MEDIA_SESSION_H_
#define RUNNER_MEDIA_SESSION_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <string>

// Windows System Media Transport Controls (the media overlay, media keys and
// Bluetooth headset buttons) for Kyndrel (PLAN.md task 4.8). Dart sends the
// current title/state on the "kyndrel/media_session" channel; button presses
// come back as method calls ("play", "pause", "next", "seekTo"...).
class MediaSession {
 public:
  // Window message used to move SMTC events (raised on a worker thread) back
  // to the platform thread, where the channel may be used.
  static constexpr UINT kButtonMessage = WM_APP + 0x42;
  static constexpr UINT kSeekMessage = WM_APP + 0x43;

  MediaSession(flutter::BinaryMessenger* messenger, HWND window);
  ~MediaSession();

  // Handles kButtonMessage / kSeekMessage; returns true if it was one.
  bool HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);

 private:
  void Update(const flutter::EncodableMap& args);
  void Send(const std::string& method,
            std::unique_ptr<flutter::EncodableValue> args = nullptr);

  struct Impl;
  std::unique_ptr<Impl> impl_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_MEDIA_SESSION_H_

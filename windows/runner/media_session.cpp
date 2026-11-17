#include "media_session.h"

#include <flutter/standard_method_codec.h>
#include <systemmediatransportcontrolsinterop.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.h>

#include <chrono>

namespace wm = winrt::Windows::Media;

namespace {

const flutter::EncodableValue* Find(const flutter::EncodableMap& map,
                                    const char* key) {
  auto it = map.find(flutter::EncodableValue(std::string(key)));
  return it == map.end() ? nullptr : &it->second;
}

std::string AsString(const flutter::EncodableValue* v) {
  if (!v) return "";
  if (auto s = std::get_if<std::string>(v)) return *s;
  return "";
}

bool AsBool(const flutter::EncodableValue* v) {
  if (!v) return false;
  if (auto b = std::get_if<bool>(v)) return *b;
  return false;
}

int64_t AsInt(const flutter::EncodableValue* v) {
  if (!v) return 0;
  if (auto i = std::get_if<int32_t>(v)) return *i;
  if (auto l = std::get_if<int64_t>(v)) return *l;
  return 0;
}

winrt::Windows::Foundation::TimeSpan Ms(int64_t ms) {
  return std::chrono::duration_cast<winrt::Windows::Foundation::TimeSpan>(
      std::chrono::milliseconds(ms));
}

}  // namespace

struct MediaSession::Impl {
  HWND window = nullptr;
  wm::SystemMediaTransportControls smtc{nullptr};
  winrt::event_token button_token{};
  winrt::event_token seek_token{};
};

MediaSession::MediaSession(flutter::BinaryMessenger* messenger, HWND window)
    : impl_(std::make_unique<Impl>()) {
  impl_->window = window;
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "kyndrel/media_session",
      &flutter::StandardMethodCodec::GetInstance());

  try {
    auto interop = winrt::get_activation_factory<
        wm::SystemMediaTransportControls,
        ISystemMediaTransportControlsInterop>();
    wm::SystemMediaTransportControls smtc{nullptr};
    winrt::check_hresult(interop->GetForWindow(
        window, winrt::guid_of<wm::SystemMediaTransportControls>(),
        winrt::put_abi(smtc)));
    impl_->smtc = smtc;
    smtc.IsEnabled(true);
    smtc.IsPlayEnabled(true);
    smtc.IsPauseEnabled(true);
    smtc.IsStopEnabled(true);
    smtc.IsFastForwardEnabled(true);
    smtc.IsRewindEnabled(true);
    smtc.PlaybackStatus(wm::MediaPlaybackStatus::Closed);

    impl_->button_token = smtc.ButtonPressed(
        [window](wm::SystemMediaTransportControls const&,
                 wm::SystemMediaTransportControlsButtonPressedEventArgs const&
                     args) {
          PostMessage(window, kButtonMessage,
                      static_cast<WPARAM>(args.Button()), 0);
        });
    impl_->seek_token = smtc.PlaybackPositionChangeRequested(
        [window](wm::SystemMediaTransportControls const&,
                 wm::PlaybackPositionChangeRequestedEventArgs const& args) {
          const auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                              args.RequestedPlaybackPosition())
                              .count();
          PostMessage(window, kSeekMessage, 0, static_cast<LPARAM>(ms));
        });
  } catch (...) {
    // No media controls (e.g. Windows Server without the feature): stay
    // silent; the app works without them.
    impl_->smtc = nullptr;
  }

  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "update") {
          if (auto args = std::get_if<flutter::EncodableMap>(call.arguments())) {
            Update(*args);
          }
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
}

MediaSession::~MediaSession() {
  if (impl_ && impl_->smtc) {
    try {
      impl_->smtc.ButtonPressed(impl_->button_token);
      impl_->smtc.PlaybackPositionChangeRequested(impl_->seek_token);
    } catch (...) {
    }
  }
}

void MediaSession::Update(const flutter::EncodableMap& args) {
  auto& smtc = impl_->smtc;
  if (!smtc) return;
  try {
    const std::string title = AsString(Find(args, "title"));
    const bool has_media = !title.empty();
    const bool playing = AsBool(Find(args, "playing"));
    smtc.PlaybackStatus(!has_media ? wm::MediaPlaybackStatus::Closed
                        : playing  ? wm::MediaPlaybackStatus::Playing
                                   : wm::MediaPlaybackStatus::Paused);
    smtc.IsNextEnabled(AsBool(Find(args, "canNext")));
    smtc.IsPreviousEnabled(AsBool(Find(args, "canPrevious")));

    auto updater = smtc.DisplayUpdater();
    updater.Type(wm::MediaPlaybackType::Video);
    updater.VideoProperties().Title(winrt::to_hstring(title));
    updater.VideoProperties().Subtitle(
        winrt::to_hstring(AsString(Find(args, "subtitle"))));
    updater.Update();

    const int64_t duration = AsInt(Find(args, "durationMs"));
    wm::SystemMediaTransportControlsTimelineProperties timeline;
    timeline.StartTime(Ms(0));
    timeline.MinSeekTime(Ms(0));
    timeline.EndTime(Ms(duration));
    timeline.MaxSeekTime(Ms(duration));
    timeline.Position(Ms(AsInt(Find(args, "positionMs"))));
    smtc.UpdateTimelineProperties(timeline);
  } catch (...) {
    // Ignore transient SMTC errors.
  }
}

void MediaSession::Send(const std::string& method,
                        std::unique_ptr<flutter::EncodableValue> args) {
  channel_->InvokeMethod(method, std::move(args));
}

bool MediaSession::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == kSeekMessage) {
    Send("seekTo",
         std::make_unique<flutter::EncodableValue>(static_cast<int64_t>(lparam)));
    return true;
  }
  if (message != kButtonMessage) return false;
  switch (static_cast<wm::SystemMediaTransportControlsButton>(wparam)) {
    case wm::SystemMediaTransportControlsButton::Play:
      Send("play");
      break;
    case wm::SystemMediaTransportControlsButton::Pause:
      Send("pause");
      break;
    case wm::SystemMediaTransportControlsButton::Stop:
      Send("stop");
      break;
    case wm::SystemMediaTransportControlsButton::Next:
      Send("next");
      break;
    case wm::SystemMediaTransportControlsButton::Previous:
      Send("previous");
      break;
    case wm::SystemMediaTransportControlsButton::FastForward:
      Send("seekBy", std::make_unique<flutter::EncodableValue>(int64_t{10000}));
      break;
    case wm::SystemMediaTransportControlsButton::Rewind:
      Send("seekBy", std::make_unique<flutter::EncodableValue>(int64_t{-10000}));
      break;
    default:
      break;
  }
  return true;
}

# mpv properties and commands used by Kyndrel

Every property, option or command Kyndrel reads or writes is listed here
(PLAN.md §2). Only `core/player/PlayerService` (through `PlayerBackend`)
uses them.

## Set at start-up

| Name | Value | Why | Task |
|---|---|---|---|
| `hwdec` | `auto-safe` | Hardware decoding with safe fallback (VideoController) | 0.5 |
| `volume-max` | `400` | Volume up to 400 % | 1.6 |
| `audio-pitch-correction` | `yes` | Keep pitch when changing speed | 2.2 |
| `sub-ass`, `sub-visibility`, `secondary-sub-visibility` | `yes` | media_kit `libass: true`: mpv draws subtitles, so image subtitles and styles work | 2.8, 2.10 |
| `ao`, `vo`, `vid` | `null`, `null`, `auto` | Engine tests only (headless) | — |

## Playback (via media_kit's Player API)

| Name | Kind | Use | Task |
|---|---|---|---|
| `loadfile` | command | Open file or URL | 1.1 |
| `stop` | command | Back to idle | 1.3 |
| `pause` | property | Play/pause | 1.1 |
| `seek` | command | Absolute seek | 1.1, 1.4 |
| `time-pos`, `duration`, `eof-reached`, `paused-for-cache`, `demuxer-cache-time`, `width`, `height` | observed | `PlaybackState` | 1.1 |
| `volume` | property | 0–400 | 1.6 |
| `speed` | property | Playback rate | 2.1 |

## Set or observed directly

| Name | Kind | Access | Use | Task |
|---|---|---|---|---|
| `mute` | property | read/write | Mute toggle | 1.6 |
| `af` | command `af add/remove @kyndrel-limiter:lavfi=[alimiter=limit=0.9]` | write | Limiter above 100 % | 1.6 |
| `track-list/count`, `track-list/N/{id,type,title,lang,codec,external,external-filename,default,forced,demux-channel-count}` | property | read | Track lists | 2.5, 2.11 |
| `sid` | property | read/write | Subtitle track; `no` = off | 2.5 |
| `secondary-sid` | property | read/write | Dual subtitles | 2.7 |
| `aid` | property | read/write | Audio track | 2.11 |
| `sub-add <path> select\|auto [title]` | command | write | External / downloaded subtitles | 2.6, 2.9 |
| `sub-auto` | option | write | `fuzzy` (or `no`) to load subtitle files next to the video | 2.6 |
| `sub-delay` | property | read/write | Subtitle sync | 2.7 |
| `audio-delay` | property | read/write | Audio sync | 2.11 |
| `sub-font`, `sub-font-size`, `sub-color`, `sub-border-color`, `sub-border-size`, `sub-back-color`, `sub-border-style`, `sub-pos`, `sub-bold`, `sub-ass-override` | option | write | Subtitle style | 2.8 |
| `sub-shadow-offset`, `sub-shadow-color` | option | write | Background box on libmpv < 0.38 (no `sub-border-style`) | 2.8 |
| `video-aspect-override` | property | write | 16:9 / 4:3 / `no` | 2.12 |
| `video-rotate` | property | write | 0/90/180/270 | 2.12 |
| `chapter-list/count`, `chapter-list/N/{time,title}` | property | read | Chapter marks | 3.6 |
| `chapter` | property | observed | Current chapter | 3.6 |
| second mpv: `vo=image`, `vo-image-{format,jpeg-quality,outdir}`, `vf=scale`, `frames=1`, `start`, `loadfile` | options/command | write | Seek-bar preview frames | 3.7 |
| `add chapter ±1` | command | write | Next/previous chapter | 3.6 |
| `ab-loop-a`, `ab-loop-b` | property | read/write | A-B loop (`no` clears) | 3.9 |
| `frame-step`, `frame-back-step` | command | write | Frame stepping | 3.9 |
| `screenshot-to-file <path> video\|subtitles` | command | write | History thumbnails (3.3), screenshots (3.8) | 3.3 |
| `hwdec-current`, `video-codec`, `width`, `height`, `container-fps`, `estimated-vf-fps`, `frame-drop-count` | property | read | `--diagnostics` overlay | 0.5 |
| `filename`, `path`, `file-format`, `file-size`, `duration`, `chapters`, `audio-params/hr-channels`, `video-params/{w,h,pixelformat,colormatrix,primaries,gamma}`, `video-bitrate`, `audio-codec`, `audio-params/{channel-count,samplerate}`, `audio-bitrate` | property | read | Media info dialog | 1.3 |

Log lines (`warn` and above) are kept in a 200-line buffer for the error
screen (1.13). Errors matching "audio device/driver/output" or "no sound"
are treated as non-fatal.

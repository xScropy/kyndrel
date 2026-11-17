# mpv properties and commands used by Kyndrel

Every property, option or command Kyndrel reads or writes is listed here
(PLAN.md §2). Only `core/player/PlayerService` may use them.

| Name | Kind | Access | Used for | Task |
|---|---|---|---|---|
| `hwdec` | option | write (`auto-safe`) | Hardware decoding with safe fallback | 0.5 |
| `hwdec-current` | property | read | Show whether hardware decoding is active | 0.5 |
| `video-codec` | property | read | Spike diagnostics, later media info | 0.5 |
| `width`, `height` | property | read | Spike diagnostics, quality badge (1.3) | 0.5 |
| `container-fps`, `estimated-vf-fps` | property | read | Spike diagnostics | 0.5 |
| `frame-drop-count` | property | read | Spike diagnostics, performance checks | 0.5 |

Planned (add rows as each task lands): `volume-max`, `volume`, `af`, `speed`,
`audio-pitch-correction`, `sid`, `secondary-sid`, `sub-add`, `sub-delay`,
`sub-pos`, `aid`, `audio-delay`, `video-aspect-override`, `panscan`,
`screenshot`, `chapter-list`.

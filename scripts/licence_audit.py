"""Licence audit (task 5.8): writes ATTRIBUTION.md.

Walks the *runtime* dependency closure of pubspec.yaml (dev dependencies
and their trees are left out), reads each package's licence from the pub
cache, classifies it, and adds the native components Kyndrel ships
(libmpv, FFmpeg, fonts). Fails if a licence is unknown or not compatible
with Kyndrel's GPL-3.0.

    python3 scripts/licence_audit.py          # rewrite ATTRIBUTION.md
    python3 scripts/licence_audit.py --check  # CI: fail if out of date

Needs `flutter pub get` first (the pub cache) and PyYAML.
"""
import os
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
PUB_CACHE = Path(os.environ.get("PUB_CACHE", Path.home() / ".pub-cache"))
FLUTTER_ROOT = Path(os.environ.get("FLUTTER_ROOT", "/opt/flutter"))

# Licences that can be combined with Kyndrel under GPL-3.0.
COMPATIBLE = {"MIT", "BSD-2-Clause", "BSD-3-Clause", "Apache-2.0", "MPL-2.0",
              "ISC", "Zlib", "LGPL-2.1+", "GPL-3.0"}


def classify(text: str) -> str:
    t = " ".join(text.split())
    if "Apache License" in t and "Version 2.0" in t:
        return "Apache-2.0"
    if "Mozilla Public License" in t and "2.0" in t:
        return "MPL-2.0"
    if "GNU LESSER GENERAL PUBLIC LICENSE" in t.upper():
        return "LGPL-2.1+"
    if "GNU GENERAL PUBLIC LICENSE" in t.upper():
        return "GPL-3.0"
    if "Permission is hereby granted, free of charge" in t:
        return "MIT"
    if "Redistribution and use in source and binary forms" in t:
        if "Neither the name" in t or "names of its contributors" in t:
            return "BSD-3-Clause"
        return "BSD-2-Clause"
    if "Permission to use, copy, modify, and/or distribute" in t:
        return "ISC"
    if "This software is provided 'as-is'" in t:
        return "Zlib"
    return "UNKNOWN"


def package_dir(name: str, info: dict) -> Path | None:
    src = info["source"]
    if src == "hosted":
        return PUB_CACHE / "hosted" / "pub.dev" / f"{name}-{info['version']}"
    if src == "sdk":
        for base in (FLUTTER_ROOT / "packages", FLUTTER_ROOT / "bin/cache/pkg"):
            if (base / name).exists():
                return base / name
    return None


def deps_of(path: Path) -> list[str]:
    spec = yaml.safe_load((path / "pubspec.yaml").read_text())
    return list((spec.get("dependencies") or {}).keys())


def licence_of(path: Path) -> tuple[str, str]:
    for name in ("LICENSE", "LICENSE.md", "LICENSE.txt", "LICENCE", "COPYING"):
        f = path / name
        if f.exists():
            return classify(f.read_text(errors="ignore")), name
    return "UNKNOWN", ""


def homepage(path: Path) -> str:
    spec = yaml.safe_load((path / "pubspec.yaml").read_text())
    return spec.get("repository") or spec.get("homepage") or ""


def runtime_packages() -> list[dict]:
    lock = yaml.safe_load((ROOT / "pubspec.lock").read_text())["packages"]
    root = yaml.safe_load((ROOT / "pubspec.yaml").read_text())
    todo = list((root.get("dependencies") or {}).keys())
    seen: dict[str, dict] = {}
    while todo:
        name = todo.pop()
        if name in seen or name not in lock:
            continue
        info = lock[name]
        path = package_dir(name, info)
        if path is None or not path.exists():
            sys.exit(f"{name}: not in the pub cache; run flutter pub get")
        spdx, file = licence_of(path)
        if spdx == "UNKNOWN" and info["source"] == "sdk":
            # SDK packages are covered by Flutter's own licence.
            spdx = classify((FLUTTER_ROOT / "LICENSE").read_text())
        seen[name] = {
            "name": name,
            "version": info["version"] if info["source"] == "hosted" else "SDK",
            "licence": spdx,
            "url": homepage(path) if info["source"] == "hosted" else
            "https://github.com/flutter/flutter",
        }
        todo.extend(deps_of(path))
    return sorted(seen.values(), key=lambda p: p["name"])


NATIVE = """\
## Native components

| Component | Where | Licence | Source |
|---|---|---|---|
| libmpv (Windows) | `mpv-dev-x86_64-20230924-git-652a1dd`, bundled by `media_kit_libs_windows_video` | GPL-2.0+ build (mpv-winbuild-cmake), with FFmpeg and its libraries | [media-kit/libmpv-win32-video-build, release 2023-09-24](https://github.com/media-kit/libmpv-win32-video-build/releases/tag/2023-09-24) |
| libmpv (macOS) | libmpv-darwin-build `v0.6.0`, `macos-universal-video-default`, bundled by `media_kit_libs_macos_video` | LGPL-2.1+ ("default" variant: no GPL parts, playback only) | [media-kit/libmpv-darwin-build v0.6.0](https://github.com/media-kit/libmpv-darwin-build/releases/tag/v0.6.0) |
| libmpv, FFmpeg (Linux `.deb`) | not bundled: the distribution's `libmpv2` package | as packaged by the distribution | the distribution's source packages |
| libmpv, FFmpeg (AppImage) | Ubuntu 24.04's `libmpv2` and FFmpeg libraries, bundled by linuxdeploy | GPL-2.0+ (Debian/Ubuntu build mpv and FFmpeg with GPL parts) | `apt-get source mpv ffmpeg` on Ubuntu 24.04; [mpv](https://github.com/mpv-player/mpv), [FFmpeg](https://ffmpeg.org/download.html) |
| SQLite | Windows/macOS: built by the `sqlite3` package; Linux: the system `libsqlite3` | Public domain | [sqlite.org](https://sqlite.org/copyright.html) |
| Flutter engine | every build | BSD-3-Clause and the licences listed in the app (Settings › About › Open-source licences) | [flutter/flutter](https://github.com/flutter/flutter) |
| Inter font | `assets/fonts/Inter.ttf` | SIL OFL 1.1 (`assets/fonts/OFL.txt`) | [rsms/inter](https://github.com/rsms/inter) |
| Noto Sans Arabic font | `assets/fonts/NotoSansArabic.ttf` | SIL OFL 1.1 (`assets/fonts/NotoSansArabic-OFL.txt`) | [notofonts/arabic](https://github.com/notofonts/arabic) |
| Material Icons | bundled by Flutter | Apache-2.0 | [google/material-design-icons](https://github.com/google/material-design-icons) |

### What this means
- Kyndrel is GPL-3.0. Every component above is GPL-3.0-compatible
  (GPL-2.0+ components are used under GPL-3.0; LGPL, MPL-2.0, Apache-2.0,
  BSD, MIT, OFL and public domain all combine with it).
- Whoever distributes Kyndrel binaries must also offer the corresponding
  source. For Kyndrel that is this repository at the release tag. For the
  bundled libmpv/FFmpeg builds it is the release pages linked above (they
  include the build scripts and pinned source versions); keep links to
  them in the release notes.
- `yt-dlp` and `ffmpeg` executables used by downloads, casting and
  subtitle translation are **not** bundled: Kyndrel runs them only if the
  user has installed them.
"""


def render(packages: list[dict]) -> str:
    rows = "\n".join(
        f"| [{p['name']}]({p['url']}) | {p['version']} | {p['licence']} |"
        if p["url"] else f"| {p['name']} | {p['version']} | {p['licence']} |"
        for p in packages
    )
    counts: dict[str, int] = {}
    for p in packages:
        counts[p["licence"]] = counts.get(p["licence"], 0) + 1
    summary = ", ".join(f"{k} {v}" for k, v in sorted(counts.items()))
    return f"""# Attribution

Kyndrel is licensed under the GNU GPL v3.0 ([LICENSE](LICENSE)). It is
built on the components below. The full licence texts ship inside the app
(Settings › About › Open-source licences).

Generated by `scripts/licence_audit.py` (task 5.8); CI fails when this file
is out of date. Do not edit by hand.

{NATIVE}
## Dart and Flutter packages (runtime)

{len(packages)} packages: {summary}.

| Package | Version | Licence |
|---|---|---|
{rows}
"""


def main() -> None:
    packages = runtime_packages()
    bad = [p for p in packages if p["licence"] not in COMPATIBLE]
    if bad:
        for p in bad:
            print(f"needs review: {p['name']} {p['version']}: {p['licence']}",
                  file=sys.stderr)
        sys.exit(1)
    text = render(packages)
    out = ROOT / "ATTRIBUTION.md"
    if "--check" in sys.argv:
        if not out.exists() or out.read_text() != text:
            sys.exit("ATTRIBUTION.md is out of date: "
                     "run python3 scripts/licence_audit.py")
        print("ATTRIBUTION.md is up to date")
        return
    out.write_text(text)
    print(f"wrote {out.relative_to(ROOT)}: {len(packages)} packages")


if __name__ == "__main__":
    main()

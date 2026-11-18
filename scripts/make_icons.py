"""Draws the Kyndrel app icon and writes every platform's sizes (task 5.6).

An orange (#F26A1B) rounded square with a white play triangle, drawn at
4x and downsampled for clean edges. Run from the repository root:

    python3 scripts/make_icons.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

ACCENT = (0xF2, 0x6A, 0x1B, 255)
ROOT = Path(__file__).resolve().parent.parent


def icon(size: int) -> Image.Image:
    s = size * 4
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # macOS-style margin so the icon sits well next to system ones.
    m = round(s * 0.09)
    d.rounded_rectangle((m, m, s - m, s - m), radius=round(s * 0.22), fill=ACCENT)
    # Play triangle, optically centred (nudged right).
    cx, cy, r = s * 0.53, s * 0.5, s * 0.22
    d.polygon(
        [(cx - r * 0.8, cy - r), (cx - r * 0.8, cy + r), (cx + r, cy)],
        fill=(255, 255, 255, 255),
    )
    return img.resize((size, size), Image.LANCZOS)


def adaptive_foreground(size: int) -> Image.Image:
    """Android adaptive-icon foreground: the play triangle alone, sized for
    the 66 % safe zone of the 108 dp canvas (task 6.1)."""
    s = size * 4
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy, r = s * 0.52, s * 0.5, s * 0.15
    d.polygon(
        [(cx - r * 0.8, cy - r), (cx - r * 0.8, cy + r), (cx + r, cy)],
        fill=(255, 255, 255, 255),
    )
    return img.resize((size, size), Image.LANCZOS)


ANDROID_DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def android() -> None:
    res = ROOT / "android/app/src/main/res"
    for name, k in ANDROID_DENSITIES.items():
        out = res / f"mipmap-{name}"
        out.mkdir(parents=True, exist_ok=True)
        icon(round(48 * k)).save(out / "ic_launcher.png")
        adaptive_foreground(round(108 * k)).save(out / "ic_launcher_foreground.png")
    anydpi = res / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '</adaptive-icon>\n'
    )
    values = res / "values"
    values.mkdir(parents=True, exist_ok=True)
    (values / "ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#F26A1B</color>\n'
        '</resources>\n'
    )


def main() -> None:
    mac = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for n in (16, 32, 64, 128, 256, 512, 1024):
        icon(n).save(mac / f"app_icon_{n}.png")
    icon(256).save(
        ROOT / "windows/runner/resources/app_icon.ico",
        sizes=[(n, n) for n in (16, 24, 32, 48, 64, 128, 256)],
    )
    linux = ROOT / "packaging/linux/icons"
    for n in (48, 128, 256, 512):
        out = linux / f"{n}x{n}"
        out.mkdir(parents=True, exist_ok=True)
        icon(n).save(out / "kyndrel.png")
    if (ROOT / "android").exists():
        android()


if __name__ == "__main__":
    main()

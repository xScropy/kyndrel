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


if __name__ == "__main__":
    main()

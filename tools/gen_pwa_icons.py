#!/usr/bin/env python3
"""
Sidewalk Kings - installable app icons.

The game is played as an installed app rather than in a browser tab, so it needs real
icons at the sizes Chrome, Android and iOS ask for. Godot's web export references these
from the generated web manifest.

Pixel art does not survive an arbitrary resize: scaling 128 to 180 directly leaves some
source pixels two screen pixels wide and others three, which reads as a wobble. Each size
is therefore nearest-neighbour upscaled to a whole multiple first, so every source pixel
stays square, and only then area-averaged down to the exact target.

Run from the project root:  python tools/gen_pwa_icons.py
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "icon.png")
# Not web/: that folder carries a .gdignore so Godot does not re-import its own export
# output, which also means anything in there cannot be referenced as a res:// path.
OUT = os.path.join(ROOT, "assets", "pwa")

# The sizes the manifest declares. 512 is what app stores and splash screens use, 180 is
# the iOS home screen, 144 is the Android legacy launcher.
SIZES = [144, 180, 512]


def render(src: Image.Image, size: int) -> Image.Image:
    if size % src.width == 0:
        return src.resize((size, size), Image.NEAREST)
    factor = -(-size // src.width)          # smallest whole multiple at or above target
    big = src.resize((src.width * factor, src.height * factor), Image.NEAREST)
    return big.resize((size, size), Image.BOX)


def main() -> None:
    if not os.path.exists(SRC):
        raise SystemExit("missing %s" % SRC)
    os.makedirs(OUT, exist_ok=True)
    src = Image.open(SRC).convert("RGBA")
    if src.width != src.height:
        raise SystemExit("icon.png must be square, got %dx%d" % src.size)

    # A maskable icon is cropped to a circle on Android, so the artwork is inset and the
    # margin filled from the existing background rather than left transparent.
    corner = src.getpixel((1, 1))
    for size in SIZES:
        img = render(src, size)
        img.save(os.path.join(OUT, "icon-%d.png" % size))
        print("  icon-%d.png" % size)

    inset = int(512 * 0.20)
    maskable = Image.new("RGBA", (512, 512), corner)
    art = render(src, 512 - inset * 2)
    maskable.paste(art, (inset, inset), art)
    maskable.save(os.path.join(OUT, "icon-512-maskable.png"))
    print("  icon-512-maskable.png  (%d px safe-area inset)" % inset)
    print("pwa icons: %d written to assets/pwa/" % (len(SIZES) + 1))


if __name__ == "__main__":
    main()

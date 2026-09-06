#!/usr/bin/env python3
"""
Sidewalk Kings - comic panels.

Story beats told as wide comic panels instead of as a dialogue box over the street.

Two rules, both of which fall out of what this project already is:

**The art is generated, like everything else.** Panels are composed from the same skyline,
facades and character sprites the game itself is built from, so a panel looks like the game
rather than like a different product bolted onto it. It also means a panel costs a couple of
kilobytes instead of three megabytes, which matters when the entire shipped package is under
four.

**The text is not baked in.** There is no font in this pipeline -- shop signs are drawn as
abstract blocks, not letters -- and painting words into a PNG would make them impossible to
restyle, impossible to translate, and blurry at any scale but one. The panel image is pure
art; `ComicPlayer` draws the speech bubble over it at runtime with the same UI font as the
rest of the game.

Run from the project root:  python tools/gen_comics.py
"""
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_world as W  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "assets", "art", "comics")
DATA = os.path.join(ROOT, "data", "comics")

# Wide and short, the shape a comic panel is. Small, because it is pixel art and the game
# upscales it: a 3:1 panel at this size fills a 16:9 screen edge to edge.
PW, PH = 480, 170


def _character(cid, scale=3, flip=False):
    """Frame 0 of a character's sheet -- their idle pose -- at panel scale."""
    path = os.path.join(ROOT, "assets", "art", "characters", cid + ".png")
    if not os.path.exists(path):
        return None
    sheet = Image.open(path).convert("RGBA")
    frame = sheet.crop((0, 0, 64, 64))
    # Trim the transparent margin so placement is by the body, not by the cell.
    bbox = frame.getbbox()
    if bbox:
        frame = frame.crop(bbox)
    frame = frame.resize((frame.width * scale, frame.height * scale), Image.NEAREST)
    if flip:
        frame = frame.transpose(Image.FLIP_LEFT_RIGHT)
    return frame


def street_panel(seed=1, warm=True, lamps=(90, 300, 430)):
    """A Riverbend street at dusk: sky, skyline, facades, road, lamplight."""
    top = (58, 46, 92) if warm else (36, 34, 58)
    bottom = (214, 126, 104) if warm else (70, 62, 96)
    im = W.gradient(PW, PH, top, bottom)

    far = W.skyline(PW, 70, (44, 36, 62), far=True, seed=seed)
    im.alpha_composite(far, (0, PH - 118))
    near = W.skyline(PW, 56, (30, 24, 44), far=False, seed=seed + 7)
    im.alpha_composite(near, (0, PH - 96))

    # A facade at each edge frames the panel and gives the eye somewhere to stop.
    for name, x in (("apartment_a", -18), ("shop_corner", PW - 92)):
        spec = dict(W.BUILDING_SPECS[name])
        b = W.building(**spec)
        b = b.resize((int(b.width * 0.62), int(b.height * 0.62)), Image.NEAREST)
        im.alpha_composite(b, (x, PH - 52 - b.height))

    from PIL import ImageDraw
    d = ImageDraw.Draw(im)
    d.rectangle([0, PH - 52, PW - 1, PH - 44], fill=(92, 88, 100))     # kerb
    d.rectangle([0, PH - 44, PW - 1, PH - 1], fill=(52, 50, 60))       # road
    d.rectangle([0, PH - 44, PW - 1, PH - 43], fill=(120, 114, 128))

    # Posts first, then the light over the top of them.
    for lx in lamps:
        d.rectangle([lx - 1, PH - 92, lx + 1, PH - 44], fill=(38, 36, 46))
        d.ellipse([lx - 5, PH - 98, lx + 5, PH - 88], fill=(255, 240, 200))

    # Lamplight pools, drawn on their own layer and composited.
    #
    # Drawing a translucent fill straight onto the panel REPLACES those pixels rather than
    # blending with them, so the first version painted near-transparent ellipses over the
    # road and the light read as three potholes.
    glow = Image.new("RGBA", (PW, PH), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for lx in lamps:
        for r, a in ((40, 30), (26, 40), (13, 60)):
            gd.ellipse([lx - r, PH - 40 - r // 3, lx + r, PH - 40 + r // 3],
                       fill=(255, 210, 148, a))
    im.alpha_composite(glow)
    return W.noise(im, 4, seed)


def compose(background, actors):
    """Drop the cast onto a background. actors: (character id, x, flip, scale).

    Framed like a comic rather than like the game: the figure is anchored near the top of
    the panel and allowed to run off the bottom edge, which is how a wide panel gets a
    character big enough to read. Anchoring their feet to the pavement instead, which is
    what the first version did, either shrinks them to nothing or clips their head off.
    """
    im = background.copy()
    for cid, x, flip, scale in actors:
        sprite = _character(cid, scale, flip)
        if sprite is None:
            continue
        im.alpha_composite(sprite, (int(x), 14))
    return im


# ---------------------------------------------------------------------------
# The comics themselves.
#
# `bubble` is where the speech bubble goes, in panel coordinates, so the art and the words
# are authored together even though only the art is baked.
# ---------------------------------------------------------------------------
def panel(art, speaker, text, bubble="left", tail=0.5):
    return dict(art=art, speaker=speaker, text=text, bubble=bubble, tail=tail)


COMICS = {
    # The opening. It exists because the game currently starts with a ten-line dialogue box
    # over an empty street, and the premise -- four gangs stopped fighting, which gangs do
    # not do for free -- is the reason for everything that follows.
    "intro": [
        panel("intro_1", "", "Riverbend. Two years away, and the ferry still smells of "
              "diesel and fried dough.", "left"),
        panel("intro_2", "", "Four blocks. Four crews. The Pigeons had the row, and "
              "everybody knew exactly whose corner they were standing on.", "left"),
        panel("intro_3", "", "Kip came home on a Tuesday, which turns out to matter.", "right"),
        panel("intro_4", "", "Because last month, for the first time in anyone's memory, "
              "the four of them stopped fighting.", "left"),
    ],
}

# art id -> how to build it
SCENES = {
    "intro_1": lambda: street_panel(seed=3, lamps=(70, 240, 410)),
    "intro_2": lambda: compose(street_panel(seed=5, lamps=(60, 250, 420)),
                               [("dez", 292, True, 5)]),
    "intro_3": lambda: compose(street_panel(seed=8, lamps=(80, 260, 400)),
                               [("kip", 74, False, 5)]),
    "intro_4": lambda: compose(street_panel(seed=11, lamps=(70, 250, 420)),
                               [("dez", 300, True, 4), ("kip", 92, False, 4)]),
}


def main():
    os.makedirs(ART, exist_ok=True)
    os.makedirs(DATA, exist_ok=True)
    for name, build in SCENES.items():
        im = build()
        im.save(os.path.join(ART, name + ".png"))
        print("  panel %-10s %dx%d" % (name, im.width, im.height))
    for cid, panels in COMICS.items():
        with open(os.path.join(DATA, cid + ".json"), "w", newline="\n") as f:
            json.dump({"id": cid, "panels": panels}, f, indent=1)
        print("  comic %-10s %d panels" % (cid, len(panels)))
    print("comics: %d" % len(COMICS))
    return 0


if __name__ == "__main__":
    sys.exit(main())

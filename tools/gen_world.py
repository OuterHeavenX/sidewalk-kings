#!/usr/bin/env python3
"""
Sidewalk Kings - original environment, prop, weapon, FX and UI art generator.

Everything here is drawn procedurally with Pillow, so all artwork is original to this project.
Run from the project root:  python tools/gen_world.py
"""
import os, math, random
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = lambda *p: os.path.join(ROOT, "assets", *p)
OUTLINE = (24, 16, 28, 255)
random.seed(20240904)

def ensure(*p):
    d = A(*p)
    os.makedirs(d, exist_ok=True)
    return d

def rgba(c, a=255):
    return (c[0], c[1], c[2], a if len(c) == 3 else c[3])

def shade(c, f):
    return (max(0, min(255, int(c[0] * f))), max(0, min(255, int(c[1] * f))), max(0, min(255, int(c[2] * f))), 255 if len(c) < 4 else c[3])

def noise(img, amount=8, seed=1):
    rnd = random.Random(seed)
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            n = rnd.randint(-amount, amount)
            px[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)), a)
    return img

def outline_alpha(img, color=OUTLINE):
    """Add a 1px dark outline around every opaque cluster."""
    w, h = img.size
    src = img.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    o = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 128:
                    o[x, y] = color
                    break
    out.alpha_composite(img)
    return out

# =====================================================================
# PROPS
# =====================================================================
def prop_trashcan():
    im = Image.new("RGBA", (28, 34), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    body = (86, 96, 104); dark = shade(body, 0.7); lite = shade(body, 1.22)
    d.polygon([(5, 8), (22, 8), (20, 31), (7, 31)], fill=body)
    for x in range(6, 22, 3):
        d.line([(x, 9), (x - 1, 30)], fill=dark)
    d.polygon([(5, 8), (10, 8), (9, 31), (7, 31)], fill=lite)
    d.ellipse([3, 3, 24, 11], fill=shade(body, 0.9))
    d.ellipse([4, 4, 23, 10], fill=lite)
    d.ellipse([10, 5, 17, 9], fill=dark)
    d.line([(5, 14), (22, 14)], fill=dark)
    d.line([(6, 24), (21, 24)], fill=dark)
    return outline_alpha(noise(im, 5, 3))

def prop_hydrant():
    im = Image.new("RGBA", (18, 26), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    red = (198, 52, 48)
    d.rectangle([5, 7, 12, 23], fill=red)
    d.rectangle([5, 7, 7, 23], fill=shade(red, 1.25))
    d.rectangle([11, 7, 12, 23], fill=shade(red, 0.72))
    d.ellipse([4, 3, 13, 10], fill=red)
    d.ellipse([5, 3, 10, 8], fill=shade(red, 1.25))
    d.rectangle([2, 11, 15, 14], fill=shade(red, 0.85))
    d.rectangle([1, 12, 3, 14], fill=shade(red, 0.7))
    d.rectangle([14, 12, 16, 14], fill=shade(red, 0.7))
    d.rectangle([3, 23, 14, 25], fill=shade(red, 0.6))
    d.rectangle([7, 1, 10, 3], fill=shade(red, 0.8))
    return outline_alpha(im)

def prop_cone():
    im = Image.new("RGBA", (18, 22), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    o = (232, 118, 40)
    d.polygon([(9, 1), (14, 18), (4, 18)], fill=o)
    d.polygon([(9, 1), (11, 18), (7, 18)], fill=shade(o, 1.2))
    d.polygon([(9, 7), (11, 12), (7, 12)], fill=(245, 245, 240))
    d.rectangle([2, 18, 15, 21], fill=shade(o, 0.8))
    return outline_alpha(im)

def prop_vending():
    im = Image.new("RGBA", (30, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    body = (56, 84, 150)
    d.rectangle([1, 1, 28, 46], fill=body)
    d.rectangle([1, 1, 4, 46], fill=shade(body, 1.25))
    d.rectangle([25, 1, 28, 46], fill=shade(body, 0.72))
    d.rectangle([4, 4, 21, 30], fill=(28, 34, 48))
    for r in range(4):
        for c in range(4):
            col = [(220, 70, 70), (240, 190, 60), (90, 200, 130), (200, 120, 220)][(r + c) % 4]
            d.rectangle([6 + c * 4, 6 + r * 6, 8 + c * 4, 10 + r * 6], fill=col)
            d.line([(6 + c * 4, 6 + r * 6), (6 + c * 4, 10 + r * 6)], fill=shade(col, 1.3))
        d.line([(5, 11 + r * 6), (20, 11 + r * 6)], fill=(60, 70, 90))
    d.rectangle([4, 4, 21, 30], outline=(120, 190, 230))
    d.rectangle([23, 6, 27, 18], fill=(20, 24, 34))
    for i in range(3):
        d.rectangle([24, 8 + i * 3, 26, 9 + i * 3], fill=(240, 120, 60))
    d.rectangle([4, 33, 24, 40], fill=(24, 28, 40))
    d.rectangle([6, 35, 22, 38], fill=(60, 70, 90))
    d.rectangle([1, 44, 28, 46], fill=shade(body, 0.55))
    return outline_alpha(noise(im, 4, 7))

def prop_bench():
    im = Image.new("RGBA", (46, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    wood = (146, 96, 56); metal = (70, 74, 82)
    for i, y in enumerate((4, 8)):
        d.rectangle([4, y, 41, y + 2], fill=shade(wood, 1.0 - i * 0.08))
    for y in (13, 16):
        d.rectangle([2, y, 43, y + 2], fill=shade(wood, 1.1 - (y - 13) * 0.02))
    d.rectangle([3, 12, 5, 23], fill=metal)
    d.rectangle([40, 12, 42, 23], fill=metal)
    d.rectangle([5, 2, 7, 13], fill=metal)
    d.rectangle([38, 2, 40, 13], fill=metal)
    d.rectangle([1, 22, 45, 23], fill=shade(metal, 0.6))
    return outline_alpha(noise(im, 6, 11))

def prop_streetlight():
    im = Image.new("RGBA", (26, 96), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    m = (58, 62, 72)
    d.rectangle([4, 10, 8, 94], fill=m)
    d.rectangle([4, 10, 5, 94], fill=shade(m, 1.3))
    d.rectangle([2, 90, 11, 95], fill=shade(m, 0.7))
    d.arc([5, 4, 22, 22], 180, 300, fill=m, width=3)
    d.rectangle([17, 8, 24, 11], fill=m)
    d.polygon([(16, 11), (25, 11), (23, 17), (18, 17)], fill=(250, 240, 190))
    d.polygon([(18, 11), (21, 11), (20, 16), (19, 16)], fill=(255, 255, 235))
    return outline_alpha(im)

def prop_fire_escape():
    """The iron zigzag up the back of a building, with a drop ladder you can reach.

    This exists because the route onto the roof was an invisible trigger volume in front
    of a plain brick facade. The door worked; there was simply nothing to see, so the only
    way to find it was to walk the whole street pressing the interact key.

    The ladder is drawn hanging down within reach rather than folded up, because the
    entire job of this sprite is to say "you can climb here" from across the street.
    """
    W, H = 34, 140
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    iron = (62, 66, 78)
    lit = shade(iron, 1.35)
    dark = shade(iron, 0.62)

    def post(x, y0, y1):
        d.rectangle([x, y0, x + 2, y1], fill=iron)
        d.rectangle([x, y0, x, y1], fill=lit)          # light catches the left edge

    LANDINGS = (30, 68, 106)
    post(3, 8, LANDINGS[-1] + 4)
    post(29, 8, LANDINGS[-1] + 4)

    for i, ly in enumerate(LANDINGS):
        # Platform, with a dark underside so it reads as having thickness.
        d.rectangle([2, ly, 31, ly + 2], fill=lit)
        d.rectangle([2, ly + 3, 31, ly + 4], fill=dark)
        # Railing: uprights with a top rail across them.
        for bx in range(4, 30, 5):
            d.rectangle([bx, ly - 9, bx, ly - 1], fill=iron)
        d.rectangle([3, ly - 10, 30, ly - 9], fill=lit)
        # The stair run down to the next landing, alternating sides so it zigzags.
        if i + 1 < len(LANDINGS):
            ny = LANDINGS[i + 1]
            left = (i % 2 == 0)
            x0, x1 = (6, 26) if left else (26, 6)
            # The stringer first, then the treads on top of it. Without the diagonal the
            # treads read as a row of floating dashes rather than as a flight of stairs.
            d.line([x0, ly + 6, x1, ny + 1], fill=dark, width=2)
            steps = 7
            for k in range(steps):
                t0 = k / float(steps)
                sx = int(x0 + (x1 - x0) * t0)
                sy = int(ly + 5 + (ny - ly - 5) * t0)
                d.rectangle([min(sx, sx + 3), sy, max(sx, sx + 3), sy + 1], fill=lit)

    # The drop ladder: the part that says this is climbable.
    lx0, lx1 = 12, 22
    d.rectangle([lx0, LANDINGS[-1] + 4, lx0 + 1, H - 4], fill=iron)
    d.rectangle([lx0, LANDINGS[-1] + 4, lx0, H - 4], fill=lit)
    d.rectangle([lx1, LANDINGS[-1] + 4, lx1 + 1, H - 4], fill=iron)
    for ry in range(LANDINGS[-1] + 9, H - 4, 6):
        d.rectangle([lx0, ry, lx1 + 1, ry + 1], fill=lit)

    # Brackets pinning it to the wall.
    for by in (14, LANDINGS[1] - 14, LANDINGS[2] - 14):
        d.rectangle([0, by, 3, by + 1], fill=dark)
        d.rectangle([30, by, 33, by + 1], fill=dark)
    return outline_alpha(im)

def prop_door_marker():
    """A small chevron that hangs over a door and points at it.

    The HUD prompt only appears within 26 pixels, which tells you a door is there once
    you are already standing in it. That is fine for a door you can see and useless for
    one you cannot, so this marks the spot from across the street.
    """
    W, H = 11, 9
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(0, 0), (10, 0), (5, 8)], fill=(255, 226, 150))
    d.polygon([(2, 1), (8, 1), (5, 5)], fill=(255, 248, 220))
    return outline_alpha(im)

def prop_fence(w=64):
    im = Image.new("RGBA", (w, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    m = (96, 102, 110)
    for x in range(0, w, 8):
        d.line([(x, 4), (x + 8, 36)], fill=m)
        d.line([(x + 8, 4), (x, 36)], fill=shade(m, 0.8))
    d.rectangle([0, 2, w - 1, 4], fill=shade(m, 1.2))
    d.rectangle([0, 35, w - 1, 37], fill=shade(m, 0.7))
    for x in range(0, w, 32):
        d.rectangle([x, 0, x + 2, 39], fill=shade(m, 0.9))
    return im

def prop_dumpster():
    im = Image.new("RGBA", (56, 36), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    g = (76, 118, 86)
    d.polygon([(2, 10), (53, 10), (50, 33), (5, 33)], fill=g)
    d.polygon([(2, 10), (10, 10), (8, 33), (5, 33)], fill=shade(g, 1.2))
    d.polygon([(45, 10), (53, 10), (50, 33), (44, 33)], fill=shade(g, 0.75))
    d.rectangle([0, 5, 55, 11], fill=shade(g, 0.9))
    d.rectangle([0, 5, 55, 7], fill=shade(g, 1.15))
    d.line([(27, 5), (27, 11)], fill=shade(g, 0.6))
    d.line([(4, 20), (51, 20)], fill=shade(g, 0.7))
    d.rectangle([6, 33, 10, 35], fill=(40, 40, 44))
    d.rectangle([45, 33, 49, 35], fill=(40, 40, 44))
    d.rectangle([18, 2, 24, 6], fill=(190, 180, 160))
    d.rectangle([30, 3, 34, 6], fill=(170, 150, 120))
    return outline_alpha(noise(im, 6, 13))

def prop_crate():
    im = Image.new("RGBA", (26, 26), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    w = (168, 120, 68)
    d.rectangle([1, 1, 24, 24], fill=w)
    d.rectangle([1, 1, 24, 4], fill=shade(w, 1.2))
    d.rectangle([1, 21, 24, 24], fill=shade(w, 0.75))
    d.line([(1, 1), (24, 24)], fill=shade(w, 0.82))
    d.line([(24, 1), (1, 24)], fill=shade(w, 0.82))
    d.rectangle([1, 1, 24, 24], outline=shade(w, 0.65))
    return outline_alpha(noise(im, 7, 17))

def prop_barrel():
    im = Image.new("RGBA", (24, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (176, 74, 52)
    d.rectangle([3, 4, 20, 30], fill=c)
    d.rectangle([3, 4, 7, 30], fill=shade(c, 1.2))
    d.rectangle([17, 4, 20, 30], fill=shade(c, 0.75))
    d.ellipse([3, 1, 20, 7], fill=shade(c, 1.1))
    d.ellipse([5, 2, 18, 6], fill=shade(c, 0.85))
    for y in (11, 22):
        d.rectangle([2, y, 21, y + 2], fill=shade(c, 0.6))
    return outline_alpha(noise(im, 6, 19))

def prop_tire():
    im = Image.new("RGBA", (26, 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, 25, 19], fill=(44, 44, 48))
    d.ellipse([6, 5, 19, 14], fill=(70, 72, 78))
    d.ellipse([8, 7, 17, 12], fill=(30, 30, 34))
    for a in range(0, 360, 30):
        x = 12.5 + 11 * math.cos(math.radians(a)); y = 9.5 + 8.5 * math.sin(math.radians(a))
        d.point((x, y), fill=(28, 28, 32))
    return outline_alpha(im)

def prop_sewer():
    im = Image.new("RGBA", (28, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, 27, 11], fill=(70, 70, 76))
    d.ellipse([2, 1, 25, 10], fill=(46, 46, 52))
    for i in range(5):
        d.line([(5 + i * 4, 3), (5 + i * 4, 8)], fill=(20, 20, 24))
    return im

def prop_phonebooth():
    im = Image.new("RGBA", (26, 56), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (54, 130, 118)
    d.rectangle([1, 2, 24, 54], fill=c)
    d.rectangle([1, 2, 4, 54], fill=shade(c, 1.2))
    d.rectangle([21, 2, 24, 54], fill=shade(c, 0.75))
    d.rectangle([4, 8, 21, 44], fill=(150, 200, 210, 210))
    d.line([(12, 8), (12, 44)], fill=shade(c, 0.8))
    d.rectangle([1, 0, 24, 4], fill=shade(c, 0.85))
    d.rectangle([5, 1, 20, 3], fill=(240, 230, 180))
    d.rectangle([1, 52, 24, 55], fill=shade(c, 0.6))
    return outline_alpha(im)

def prop_sign(text_color=(240, 90, 80)):
    im = Image.new("RGBA", (34, 44), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([15, 14, 18, 43], fill=(70, 70, 78))
    d.rectangle([2, 2, 31, 16], fill=(40, 40, 50))
    d.rectangle([4, 4, 29, 14], fill=text_color)
    for i in range(3):
        d.rectangle([6 + i * 8, 7, 11 + i * 8, 11], fill=(250, 250, 240))
    return outline_alpha(im)

def prop_graffiti(seed=1):
    rnd = random.Random(seed)
    im = Image.new("RGBA", (48, 28), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cols = [(230, 70, 120), (90, 200, 230), (250, 200, 60), (150, 90, 220), (90, 220, 130)]
    for i in range(4):
        c = rnd.choice(cols)
        x = rnd.randint(2, 30); y = rnd.randint(3, 16)
        w = rnd.randint(8, 16); h = rnd.randint(6, 10)
        d.ellipse([x, y, x + w, y + h], fill=(c[0], c[1], c[2], 190))
    for i in range(3):
        c = rnd.choice(cols)
        pts = [(rnd.randint(2, 45), rnd.randint(2, 25)) for _ in range(4)]
        d.line(pts, fill=(c[0], c[1], c[2], 230), width=2)
    return im

def prop_puddle():
    im = Image.new("RGBA", (34, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, 33, 11], fill=(70, 96, 120, 130))
    d.ellipse([4, 2, 24, 8], fill=(120, 160, 190, 110))
    d.arc([2, 1, 30, 10], 200, 340, fill=(180, 210, 230, 150))
    return im

def prop_bollard():
    im = Image.new("RGBA", (12, 26), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (180, 170, 60)
    d.rectangle([3, 4, 8, 24], fill=c)
    d.rectangle([3, 4, 4, 24], fill=shade(c, 1.25))
    d.ellipse([2, 1, 9, 7], fill=shade(c, 1.1))
    d.rectangle([2, 12, 9, 15], fill=(240, 240, 240))
    return outline_alpha(im)

def prop_car(body=(190, 60, 60)):
    im = Image.new("RGBA", (86, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(6, 26), (12, 14), (30, 10), (56, 10), (72, 15), (80, 26), (80, 33), (6, 33)], fill=body)
    d.polygon([(6, 26), (12, 14), (30, 10), (34, 10), (26, 26)], fill=shade(body, 1.18))
    d.polygon([(6, 29), (80, 29), (80, 33), (6, 33)], fill=shade(body, 0.7))
    d.polygon([(16, 24), (21, 15), (38, 12), (38, 24)], fill=(150, 190, 210))
    d.polygon([(42, 24), (42, 12), (56, 12), (66, 17), (68, 24)], fill=(130, 170, 195))
    d.polygon([(16, 24), (21, 15), (26, 14), (22, 24)], fill=(190, 220, 235))
    d.rectangle([2, 24, 7, 28], fill=(250, 240, 190))
    d.rectangle([79, 24, 84, 28], fill=(230, 70, 60))
    for cx in (22, 64):
        d.ellipse([cx - 8, 27, cx + 8, 39], fill=(36, 36, 40))
        d.ellipse([cx - 4, 30, cx + 4, 36], fill=(120, 124, 130))
        d.ellipse([cx - 2, 32, cx + 2, 35], fill=(70, 72, 78))
    return outline_alpha(im)

def prop_awning(c=(210, 70, 70)):
    im = Image.new("RGBA", (72, 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i in range(9):
        col = c if i % 2 == 0 else (245, 240, 230)
        d.polygon([(i * 8, 0), (i * 8 + 8, 0), (i * 8 + 8, 14), (i * 8, 14)], fill=col)
        d.polygon([(i * 8, 14), (i * 8 + 4, 18), (i * 8 + 8, 14)], fill=shade(col, 0.85))
    d.rectangle([0, 0, 71, 2], fill=shade(c, 0.6))
    return im

def prop_bin_bags():
    im = Image.new("RGBA", (34, 22), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for (x, y, r, col) in ((8, 12, 8, (52, 52, 60)), (20, 13, 7, (40, 40, 48)), (27, 15, 5, (58, 58, 66))):
        d.ellipse([x - r, y - r, x + r, y + r], fill=col)
        d.ellipse([x - r + 2, y - r + 1, x - 1, y + 1], fill=shade(col, 1.35))
        d.polygon([(x - 2, y - r), (x + 2, y - r), (x, y - r - 3)], fill=shade(col, 0.8))
    return outline_alpha(im)

def prop_flyer():
    im = Image.new("RGBA", (14, 18), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([1, 1, 12, 16], fill=(245, 238, 214))
    d.rectangle([3, 3, 10, 6], fill=(200, 60, 60))
    for y in (8, 10, 12, 14):
        d.line([(3, y), (10, y)], fill=(120, 110, 100))
    return outline_alpha(im)

def prop_locker():
    im = Image.new("RGBA", (30, 52), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (92, 106, 120)
    d.rectangle([1, 1, 28, 50], fill=c)
    d.rectangle([1, 1, 4, 50], fill=shade(c, 1.2))
    d.rectangle([25, 1, 28, 50], fill=shade(c, 0.75))
    d.line([(15, 1), (15, 50)], fill=shade(c, 0.6))
    for x in (8, 22):
        for y in range(6, 14, 2):
            d.line([(x - 4, y), (x + 4, y)], fill=shade(c, 0.7))
    d.rectangle([12, 24, 14, 28], fill=(220, 200, 90))
    d.rectangle([17, 24, 19, 28], fill=(220, 200, 90))
    d.rectangle([1, 50, 28, 51], fill=shade(c, 0.5))
    return outline_alpha(noise(im, 5, 23))

def prop_pallet():
    im = Image.new("RGBA", (40, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    w = (150, 108, 62)
    for y in (0, 5, 10):
        d.rectangle([0, y, 39, y + 2], fill=shade(w, 1.0 - y * 0.01))
    for x in (2, 18, 34):
        d.rectangle([x, 0, x + 3, 13], fill=shade(w, 0.85))
    return outline_alpha(noise(im, 6, 29))

def prop_pipe_stack():
    im = Image.new("RGBA", (44, 26), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (120, 126, 134)
    for (x, y) in ((6, 16), (20, 16), (34, 16), (13, 6), (27, 6)):
        d.ellipse([x - 7, y - 7, x + 7, y + 7], fill=c)
        d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(46, 48, 54))
        d.arc([x - 7, y - 7, x + 7, y + 7], 160, 300, fill=shade(c, 1.3), width=2)
    return outline_alpha(im)

def prop_ac_unit():
    im = Image.new("RGBA", (28, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (150, 152, 156)
    d.rectangle([1, 1, 26, 22], fill=c)
    d.rectangle([1, 1, 26, 4], fill=shade(c, 1.2))
    d.ellipse([5, 5, 22, 20], fill=shade(c, 0.7))
    d.ellipse([7, 7, 20, 18], fill=(60, 62, 68))
    for a in range(0, 360, 60):
        x1 = 13.5 + 6 * math.cos(math.radians(a)); y1 = 12.5 + 5.5 * math.sin(math.radians(a))
        d.line([(13.5, 12.5), (x1, y1)], fill=(120, 122, 128), width=2)
    return outline_alpha(im)


def prop_desk():
    im = Image.new("RGBA", (40, 26), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    top = (150, 118, 84)
    d.rectangle([0, 4, 39, 10], fill=top)
    d.rectangle([0, 4, 39, 5], fill=shade(top, 1.18))
    d.rectangle([2, 11, 8, 25], fill=shade(top, 0.72))
    d.rectangle([31, 11, 37, 25], fill=shade(top, 0.72))
    d.rectangle([9, 11, 30, 18], fill=shade(top, 0.62))
    for i in range(3):
        d.rectangle([12, 12 + i * 2, 27, 12 + i * 2], fill=shade(top, 0.5))
    d.rectangle([14, 0, 30, 4], fill=(238, 236, 228))
    d.line([(15, 1), (28, 1)], fill=(180, 178, 170))
    d.line([(15, 3), (26, 3)], fill=(180, 178, 170))
    return outline_alpha(noise(im, 4, 91))

def prop_filing_cabinet():
    im = Image.new("RGBA", (24, 44), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (120, 124, 132)
    d.rectangle([1, 1, 22, 42], fill=c)
    d.rectangle([1, 1, 4, 42], fill=shade(c, 1.2))
    d.rectangle([19, 1, 22, 42], fill=shade(c, 0.74))
    for i in range(4):
        y = 4 + i * 10
        d.rectangle([4, y, 19, y + 8], fill=shade(c, 0.86))
        d.rectangle([9, y + 3, 14, y + 4], fill=shade(c, 0.55))
    return outline_alpha(noise(im, 4, 92))

def prop_turnstile():
    im = Image.new("RGBA", (26, 34), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (118, 124, 134)
    d.rectangle([9, 10, 16, 33], fill=c)
    d.rectangle([9, 10, 11, 33], fill=shade(c, 1.25))
    d.ellipse([7, 5, 18, 14], fill=shade(c, 0.85))
    for a in (0, 120, 240):
        x = 12.5 + 11 * math.cos(math.radians(a))
        y = 16 + 4 * math.sin(math.radians(a))
        d.line([(12.5, 16), (x, y)], fill=(176, 180, 188), width=3)
    d.rectangle([6, 31, 19, 33], fill=shade(c, 0.6))
    d.rectangle([10, 18, 15, 21], fill=(90, 200, 130))
    return outline_alpha(im)

def prop_ticket_machine():
    im = Image.new("RGBA", (24, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (58, 76, 104)
    d.rectangle([2, 2, 21, 38], fill=c)
    d.rectangle([2, 2, 5, 38], fill=shade(c, 1.25))
    d.rectangle([18, 2, 21, 38], fill=shade(c, 0.72))
    d.rectangle([5, 6, 18, 18], fill=(30, 38, 54))
    d.rectangle([6, 7, 17, 13], fill=(120, 200, 190))
    for i in range(3):
        d.rectangle([6, 21 + i * 4, 10 + i, 23 + i * 4], fill=(200, 200, 208))
    d.rectangle([13, 22, 17, 30], fill=(210, 180, 70))
    d.rectangle([4, 36, 19, 38], fill=shade(c, 0.55))
    return outline_alpha(noise(im, 4, 61))

def prop_metro_sign():
    im = Image.new("RGBA", (40, 26), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 39, 19], fill=(28, 36, 56))
    d.rectangle([2, 2, 37, 17], fill=(58, 118, 190))
    for i in range(4):
        d.rectangle([6 + i * 8, 7, 10 + i * 8, 12], fill=(238, 240, 246))
    d.rectangle([18, 19, 21, 25], fill=(70, 74, 84))
    return outline_alpha(im)

def prop_roof_vent():
    im = Image.new("RGBA", (28, 22), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (140, 142, 148)
    d.rectangle([3, 6, 24, 20], fill=c)
    d.rectangle([3, 6, 24, 9], fill=shade(c, 1.2))
    d.ellipse([1, 1, 26, 9], fill=shade(c, 0.9))
    d.ellipse([4, 2, 23, 8], fill=(46, 48, 54))
    for x in range(6, 22, 4):
        d.line([(x, 12), (x, 19)], fill=shade(c, 0.75))
    return outline_alpha(noise(im, 5, 67))

def prop_aerial():
    im = Image.new("RGBA", (22, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (96, 100, 108)
    d.line([(11, 4), (11, 39)], fill=c, width=2)
    for i, y in enumerate((8, 14, 20, 26)):
        w = 9 - i
        d.line([(11 - w, y), (11 + w, y)], fill=c)
    d.rectangle([7, 37, 15, 39], fill=shade(c, 0.7))
    return outline_alpha(im)

def prop_satellite_dish():
    im = Image.new("RGBA", (26, 26), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (206, 204, 198)
    d.ellipse([2, 2, 20, 20], fill=c)
    d.ellipse([5, 5, 17, 17], fill=shade(c, 0.86))
    d.line([(11, 11), (20, 22)], fill=(110, 110, 118), width=2)
    d.rectangle([16, 21, 24, 24], fill=(90, 92, 100))
    return outline_alpha(im)

def prop_planter():
    im = Image.new("RGBA", (26, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (156, 106, 74)
    d.polygon([(3, 10), (22, 10), (20, 23), (5, 23)], fill=c)
    d.polygon([(3, 10), (8, 10), (7, 23), (5, 23)], fill=shade(c, 1.2))
    for (x, y, r) in ((8, 7, 5), (14, 5, 6), (19, 8, 4)):
        d.ellipse([x - r, y - r, x + r, y + r], fill=(84, 148, 84))
        d.ellipse([x - r + 1, y - r + 1, x, y], fill=(120, 186, 110))
    return outline_alpha(im)

def prop_laundry_line(w=56):
    im = Image.new("RGBA", (w, 26), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.line([(0, 3), (w - 1, 5)], fill=(150, 140, 120))
    cols = [(226, 96, 110), (240, 226, 180), (110, 170, 220), (150, 210, 150)]
    for i, x in enumerate(range(4, w - 12, 13)):
        c = cols[i % len(cols)]
        d.rectangle([x, 4, x + 9, 18], fill=c)
        d.rectangle([x, 4, x + 3, 18], fill=shade(c, 1.18))
        d.rectangle([x, 4, x + 9, 5], fill=shade(c, 0.7))
    return im

PROPS = {
    "trashcan": prop_trashcan, "hydrant": prop_hydrant, "cone": prop_cone, "vending": prop_vending,
    "bench": prop_bench, "streetlight": prop_streetlight, "dumpster": prop_dumpster, "crate": prop_crate,
    "barrel": prop_barrel, "tire": prop_tire, "sewer_grate": prop_sewer, "phonebooth": prop_phonebooth,
    "sign": prop_sign, "puddle": prop_puddle, "bollard": prop_bollard, "bin_bags": prop_bin_bags,
    "flyer": prop_flyer, "locker": prop_locker, "pallet": prop_pallet, "pipe_stack": prop_pipe_stack,
    "ac_unit": prop_ac_unit, "turnstile": prop_turnstile, "ticket_machine": prop_ticket_machine,
    "metro_sign": prop_metro_sign, "roof_vent": prop_roof_vent, "aerial": prop_aerial,
    "satellite_dish": prop_satellite_dish, "planter": prop_planter,
    "desk": prop_desk, "filing_cabinet": prop_filing_cabinet,
    "fire_escape": prop_fire_escape, "door_marker": prop_door_marker,
    "laundry_line": lambda: prop_laundry_line(56),
    "fence": lambda: prop_fence(64),
    "graffiti_a": lambda: prop_graffiti(1), "graffiti_b": lambda: prop_graffiti(5), "graffiti_c": lambda: prop_graffiti(9),
    "car_red": lambda: prop_car((190, 60, 60)), "car_blue": lambda: prop_car((60, 100, 190)),
    "car_yellow": lambda: prop_car((220, 180, 60)),
    "awning_red": lambda: prop_awning((210, 70, 70)), "awning_green": lambda: prop_awning((70, 160, 100)),
    "awning_blue": lambda: prop_awning((70, 120, 200)),
}

# =====================================================================
# WEAPONS
# =====================================================================
def w_bat():
    im = Image.new("RGBA", (34, 10), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    w = (196, 154, 96)
    d.polygon([(2, 4), (10, 3), (30, 1), (32, 5), (30, 8), (10, 6), (2, 5)], fill=w)
    d.polygon([(12, 3), (30, 1), (31, 3), (12, 4)], fill=shade(w, 1.18))
    d.polygon([(12, 6), (30, 8), (31, 6), (12, 5)], fill=shade(w, 0.78))
    d.rectangle([1, 3, 8, 6], fill=(70, 60, 60))
    d.rectangle([0, 2, 2, 7], fill=(50, 42, 44))
    return outline_alpha(im)

def w_pipe():
    im = Image.new("RGBA", (32, 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (140, 146, 154)
    d.rectangle([1, 2, 30, 5], fill=c)
    d.rectangle([1, 2, 30, 3], fill=shade(c, 1.28))
    d.rectangle([1, 5, 30, 5], fill=shade(c, 0.7))
    d.rectangle([27, 1, 31, 6], fill=shade(c, 0.85))
    d.rectangle([1, 1, 4, 6], fill=shade(c, 0.85))
    return outline_alpha(im)

def w_plank():
    im = Image.new("RGBA", (36, 10), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    w = (162, 116, 70)
    d.rectangle([1, 2, 34, 7], fill=w)
    d.line([(2, 3), (33, 3)], fill=shade(w, 1.2))
    d.line([(2, 6), (33, 6)], fill=shade(w, 0.78))
    for x in (8, 17, 26):
        d.line([(x, 2), (x + 2, 7)], fill=shade(w, 0.86))
    d.rectangle([29, 1, 31, 3], fill=(120, 120, 128))
    return outline_alpha(im)

def w_bottle():
    im = Image.new("RGBA", (12, 22), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    g = (90, 170, 110)
    d.rectangle([3, 8, 8, 20], fill=(g[0], g[1], g[2], 220))
    d.rectangle([4, 3, 7, 8], fill=(g[0], g[1], g[2], 220))
    d.rectangle([3, 8, 4, 20], fill=(170, 220, 180, 220))
    d.rectangle([4, 1, 7, 3], fill=(200, 190, 90))
    d.rectangle([3, 12, 8, 16], fill=(240, 235, 215))
    return outline_alpha(im)

def w_brick():
    im = Image.new("RGBA", (16, 10), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (176, 84, 62)
    d.rectangle([1, 2, 14, 8], fill=c)
    d.rectangle([1, 2, 14, 3], fill=shade(c, 1.2))
    d.rectangle([1, 7, 14, 8], fill=shade(c, 0.75))
    return outline_alpha(noise(im, 8, 31))

def w_chair():
    im = Image.new("RGBA", (22, 28), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    w = (150, 100, 60)
    d.rectangle([4, 2, 7, 26], fill=w)
    d.rectangle([4, 14, 19, 17], fill=shade(w, 1.1))
    d.rectangle([16, 17, 19, 26], fill=shade(w, 0.85))
    for y in (4, 8, 12):
        d.rectangle([7, y, 15, y + 2], fill=shade(w, 0.95))
    d.rectangle([4, 24, 19, 26], fill=shade(w, 0.75))
    return outline_alpha(im)

def w_basketball():
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (222, 122, 52)
    d.ellipse([0, 0, 15, 15], fill=c)
    d.ellipse([2, 2, 9, 9], fill=shade(c, 1.15))
    d.arc([0, 0, 15, 15], 0, 360, fill=shade(c, 0.6))
    d.line([(0, 8), (15, 8)], fill=(60, 36, 24))
    d.line([(8, 0), (8, 15)], fill=(60, 36, 24))
    d.arc([-4, 0, 8, 15], 270, 90, fill=(60, 36, 24))
    d.arc([8, 0, 20, 15], 90, 270, fill=(60, 36, 24))
    return outline_alpha(im)

def w_trashcan_lid():
    im = Image.new("RGBA", (22, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (110, 118, 126)
    d.ellipse([0, 2, 21, 13], fill=c)
    d.ellipse([2, 3, 19, 10], fill=shade(c, 1.2))
    d.ellipse([7, 4, 14, 8], fill=shade(c, 0.7))
    d.rectangle([9, 0, 12, 4], fill=shade(c, 0.85))
    return outline_alpha(im)

def w_mop():
    im = Image.new("RGBA", (34, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([1, 6, 24, 8], fill=(180, 140, 90))
    d.line([(1, 6), (24, 6)], fill=(210, 175, 125))
    for i in range(9):
        d.line([(24 + (i % 4), 4 + i), (32, 2 + i)], fill=(220, 218, 205))
    d.rectangle([22, 4, 26, 10], fill=(120, 130, 140))
    return outline_alpha(im)

def w_traffic_cone():
    return prop_cone()

WEAPONS_ART = {
    "bat": w_bat, "pipe": w_pipe, "plank": w_plank, "bottle": w_bottle, "brick": w_brick,
    "chair": w_chair, "basketball": w_basketball, "trash_lid": w_trashcan_lid, "mop": w_mop,
    "cone": w_traffic_cone, "trashcan_weapon": prop_trashcan,
}

# =====================================================================
# PICKUPS / ITEMS
# =====================================================================
def coin(size=10, col=(250, 205, 70)):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, size - 1, size - 1], fill=col)
    d.ellipse([1, 1, size - 3, size - 3], fill=shade(col, 1.2))
    d.ellipse([size // 3, size // 3, size - size // 3, size - size // 3], fill=shade(col, 0.78))
    return outline_alpha(im)

def bill():
    im = Image.new("RGBA", (16, 10), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([1, 2, 14, 8], fill=(120, 190, 130))
    d.rectangle([2, 3, 13, 7], fill=(150, 215, 155))
    d.ellipse([6, 3, 10, 7], fill=(90, 150, 100))
    return outline_alpha(im)

def food_icon(kind, c1, c2):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if kind == "burger":
        d.ellipse([1, 3, 14, 9], fill=(220, 170, 90))
        d.rectangle([1, 7, 14, 9], fill=(90, 170, 90))
        d.rectangle([2, 9, 13, 11], fill=(140, 80, 50))
        d.ellipse([1, 10, 14, 14], fill=(210, 160, 80))
        for x in (4, 7, 10):
            d.point((x, 5), fill=(250, 240, 200))
    elif kind == "noodles":
        d.ellipse([1, 6, 14, 14], fill=c1)
        d.ellipse([2, 7, 13, 12], fill=(240, 225, 190))
        for x in range(3, 12, 2):
            d.line([(x, 4), (x + 1, 8)], fill=(230, 200, 120))
        d.line([(10, 2), (13, 7)], fill=(150, 100, 60))
    elif kind == "drink":
        d.polygon([(3, 4), (12, 4), (10, 15), (5, 15)], fill=c1)
        d.polygon([(4, 5), (7, 5), (6, 14), (5, 14)], fill=shade(c1, 1.3))
        d.rectangle([2, 2, 13, 4], fill=(240, 240, 240))
        d.line([(9, 0), (10, 4)], fill=(220, 80, 80))
    elif kind == "donut":
        d.ellipse([1, 3, 14, 14], fill=(220, 170, 100))
        d.ellipse([1, 3, 14, 11], fill=c1)
        d.ellipse([6, 7, 9, 10], fill=(0, 0, 0, 0))
        for (x, y) in ((4, 6), (8, 5), (10, 8), (6, 9)):
            d.point((x, y), fill=c2)
    elif kind == "skewer":
        d.line([(2, 14), (13, 3)], fill=(180, 150, 110))
        for i, y in enumerate((10, 7, 4)):
            d.ellipse([2 + i * 3, y - 2, 7 + i * 3, y + 3], fill=c1 if i % 2 == 0 else c2)
    elif kind == "sandwich":
        d.polygon([(1, 12), (8, 2), (15, 12)], fill=(230, 200, 140))
        d.polygon([(3, 11), (8, 5), (13, 11)], fill=(200, 90, 80))
        d.polygon([(4, 12), (8, 8), (12, 12)], fill=(120, 190, 110))
    elif kind == "icecream":
        d.polygon([(4, 8), (12, 8), (8, 15)], fill=(210, 170, 100))
        d.ellipse([2, 2, 13, 10], fill=c1)
        d.ellipse([4, 3, 9, 7], fill=shade(c1, 1.25))
        d.ellipse([6, 1, 10, 4], fill=c2)
    elif kind == "soup":
        d.ellipse([1, 5, 14, 14], fill=(230, 230, 235))
        d.ellipse([3, 6, 12, 11], fill=c1)
        d.arc([2, 1, 7, 6], 180, 360, fill=(200, 200, 210))
        d.arc([8, 1, 13, 6], 180, 360, fill=(200, 200, 210))
    elif kind == "pizza":
        d.polygon([(8, 1), (15, 14), (1, 14)], fill=(230, 190, 110))
        d.polygon([(8, 4), (13, 13), (3, 13)], fill=(220, 130, 80))
        for (x, y) in ((7, 8), (10, 11), (5, 11)):
            d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=(190, 60, 60))
    elif kind == "candy":
        d.ellipse([4, 5, 11, 12], fill=c1)
        d.polygon([(4, 8), (0, 5), (0, 11)], fill=c2)
        d.polygon([(11, 8), (15, 5), (15, 11)], fill=c2)
    elif kind == "coffee":
        d.rectangle([3, 4, 12, 14], fill=(240, 240, 235))
        d.rectangle([3, 4, 12, 6], fill=(160, 100, 60))
        d.arc([10, 6, 15, 11], 270, 90, fill=(230, 230, 225), width=2)
        d.rectangle([4, 8, 11, 10], fill=(200, 120, 70))
    elif kind == "book":
        d.rectangle([2, 2, 13, 14], fill=c1)
        d.rectangle([3, 3, 12, 13], fill=shade(c1, 1.2))
        d.rectangle([2, 2, 4, 14], fill=shade(c1, 0.7))
        for y in (6, 8, 10):
            d.line([(6, y), (11, y)], fill=(250, 250, 240))
    else:
        d.ellipse([2, 2, 13, 13], fill=c1)
    return outline_alpha(im)

# =====================================================================
# FX
# =====================================================================
def fx_spark(size, col, rays=6, seed=1):
    frames = []
    rnd = random.Random(seed)
    angles = [rnd.uniform(0, math.tau) for _ in range(rays)]
    for f in range(4):
        im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        c = size / 2
        t = f / 3.0
        r = size * (0.16 + 0.34 * t)
        a = int(255 * (1.0 - t * 0.85))
        d.ellipse([c - r * 0.6, c - r * 0.6, c + r * 0.6, c + r * 0.6], fill=(255, 255, 255, a))
        for ang in angles:
            x = c + math.cos(ang) * r
            y = c + math.sin(ang) * r
            d.line([(c, c), (x, y)], fill=(col[0], col[1], col[2], a), width=max(1, int(size / 12)))
        frames.append(im)
    return frames

def fx_dust(size=16):
    frames = []
    for f in range(4):
        im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        t = f / 3.0
        a = int(190 * (1 - t))
        for i, off in enumerate((-5, 0, 5)):
            r = 2 + t * 4 + i % 2
            x = size / 2 + off * (0.6 + t)
            y = size - 3 - t * 4
            d.ellipse([x - r, y - r, x + r, y + r], fill=(214, 206, 190, a))
        frames.append(im)
    return frames

def fx_impact_ring(size=24, col=(255, 240, 190)):
    frames = []
    for f in range(4):
        im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        t = f / 3.0
        r = 2 + t * (size / 2 - 3)
        a = int(230 * (1 - t))
        d.ellipse([size / 2 - r, size / 2 - r * 0.55, size / 2 + r, size / 2 + r * 0.55], outline=(col[0], col[1], col[2], a), width=2)
        frames.append(im)
    return frames

def fx_shadow(w=22, h=8):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, w - 1, h - 1], fill=(10, 8, 16, 110))
    d.ellipse([2, 1, w - 3, h - 2], fill=(10, 8, 16, 80))
    return im

def fx_star(size=12, col=(255, 230, 120)):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = size / 2
    pts = []
    for i in range(10):
        r = c - 1 if i % 2 == 0 else c * 0.42
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((c + math.cos(a) * r, c + math.sin(a) * r))
    d.polygon(pts, fill=col)
    return outline_alpha(im)

def fx_sweat(size=8):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([1, 2, 6, 7], fill=(150, 210, 245))
    d.polygon([(3.5, 0), (6, 4), (1, 4)], fill=(150, 210, 245))
    d.ellipse([2, 3, 4, 5], fill=(220, 245, 255))
    return outline_alpha(im)

def write_strip(frames, path):
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * w, 0), f)
    sheet.save(path)

# =====================================================================
# TILESET + BACKGROUNDS
# =====================================================================
TILE = 16

def tile_sidewalk(v=0):
    im = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    base = (168, 164, 158) if v == 0 else (158, 154, 150)
    d.rectangle([0, 0, TILE - 1, TILE - 1], fill=base)
    d.line([(0, 0), (TILE - 1, 0)], fill=shade(base, 1.12))
    d.line([(0, TILE - 1), (TILE - 1, TILE - 1)], fill=shade(base, 0.82))
    d.line([(0, 0), (0, TILE - 1)], fill=shade(base, 1.06))
    d.line([(TILE - 1, 0), (TILE - 1, TILE - 1)], fill=shade(base, 0.86))
    return noise(im, 6, 100 + v)

def tile_asphalt(v=0):
    im = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    base = (74, 72, 82) if v == 0 else (68, 66, 76)
    d.rectangle([0, 0, TILE - 1, TILE - 1], fill=base)
    if v == 2:
        d.rectangle([2, 6, 13, 9], fill=(206, 196, 120))
    return noise(im, 9, 200 + v)

def tile_curb():
    im = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, TILE - 1, 5], fill=(178, 174, 168))
    d.rectangle([0, 0, TILE - 1, 1], fill=(198, 194, 188))
    d.rectangle([0, 6, TILE - 1, TILE - 1], fill=(74, 72, 82))
    d.line([(0, 6), (TILE - 1, 6)], fill=(46, 44, 52))
    return noise(im, 6, 300)

def tile_brick(c=(150, 78, 62)):
    im = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, TILE - 1, TILE - 1], fill=shade(c, 0.7))
    for row in range(4):
        y = row * 4
        off = 0 if row % 2 == 0 else 4
        for bx in range(-1, 3):
            x = bx * 8 + off
            d.rectangle([x, y, x + 6, y + 2], fill=c)
            d.line([(x, y), (x + 6, y)], fill=shade(c, 1.18))
    return noise(im, 7, 400)

def tile_concrete(c=(118, 116, 124)):
    im = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, TILE - 1, TILE - 1], fill=c)
    d.line([(0, 0), (TILE - 1, 0)], fill=shade(c, 1.1))
    return noise(im, 8, 500)

def tile_metal(c=(96, 104, 112)):
    im = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, TILE - 1, TILE - 1], fill=c)
    for x in range(0, TILE, 4):
        d.line([(x, 0), (x, TILE - 1)], fill=shade(c, 0.86))
        d.line([(x + 1, 0), (x + 1, TILE - 1)], fill=shade(c, 1.12))
    return noise(im, 5, 600)

def tile_tile_floor():
    """Station floor. The two tones are deliberately close together.

    They used to differ by about 40%, which reads as a chessboard rather than a floor and
    became the loudest thing on screen once area lighting arrived. Tiling now reads from
    the grout line instead of from value contrast, which survives being lit.
    """
    im = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i in range(2):
        for j in range(2):
            c = (188, 180, 166) if (i + j) % 2 == 0 else (176, 168, 154)
            d.rectangle([i * 8, j * 8, i * 8 + 7, j * 8 + 7], fill=c)
    grout = (150, 143, 132)
    for k in (0, 8):
        d.line([(k, 0), (k, TILE - 1)], fill=grout)
        d.line([(0, k), (TILE - 1, k)], fill=grout)
    return noise(im, 3, 700)

def tile_dirt():
    im = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, TILE - 1, TILE - 1], fill=(112, 92, 70))
    return noise(im, 12, 800)

def tile_wood_floor():
    im = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (138, 96, 58)
    d.rectangle([0, 0, TILE - 1, TILE - 1], fill=c)
    for y in range(0, TILE, 5):
        d.line([(0, y), (TILE - 1, y)], fill=shade(c, 0.8))
        d.line([(0, y + 1), (TILE - 1, y + 1)], fill=shade(c, 1.12))
    return noise(im, 7, 900)

TILES = [
    ("sidewalk_a", tile_sidewalk(0)), ("sidewalk_b", tile_sidewalk(1)),
    ("asphalt_a", tile_asphalt(0)), ("asphalt_b", tile_asphalt(1)), ("asphalt_line", tile_asphalt(2)),
    ("curb", tile_curb()), ("brick_red", tile_brick((150, 78, 62))), ("brick_tan", tile_brick((168, 140, 100))),
    ("concrete", tile_concrete()), ("metal", tile_metal()), ("tile_floor", tile_tile_floor()),
    ("dirt", tile_dirt()), ("wood_floor", tile_wood_floor()),
]

def build_tileset():
    cols = 8
    rows = (len(TILES) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * TILE, rows * TILE), (0, 0, 0, 0))
    for i, (name, im) in enumerate(TILES):
        sheet.paste(im, ((i % cols) * TILE, (i // cols) * TILE))
    sheet.save(A("art", "tilesets", "city_tiles.png"))
    return {name: (i % cols, i // cols) for i, (name, _) in enumerate(TILES)}

# ---- Building facades (drawn as reusable sprites, not tiles) ----
def building(w, h, wall, roof=None, windows=(3, 3), win_col=(120, 180, 210), door=True,
             door_col=(90, 60, 44), sign=None, sign_col=(220, 80, 70), style="brick", seed=1):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rnd = random.Random(seed)
    d.rectangle([0, 0, w - 1, h - 1], fill=wall)
    # wall texture
    if style == "brick":
        for row in range(0, h, 5):
            off = 0 if (row // 5) % 2 == 0 else 5
            for x in range(-10, w, 10):
                d.rectangle([x + off, row, x + off + 8, row + 3], fill=shade(wall, 1.06))
                d.line([(x + off, row), (x + off + 8, row)], fill=shade(wall, 1.16))
    elif style == "panel":
        for x in range(0, w, 14):
            d.line([(x, 0), (x, h - 1)], fill=shade(wall, 0.9))
            d.line([(x + 1, 0), (x + 1, h - 1)], fill=shade(wall, 1.08))
    elif style == "stucco":
        noise(im, 9, seed)
    # roof lip
    rc = roof or shade(wall, 0.7)
    d.rectangle([0, 0, w - 1, 5], fill=rc)
    d.rectangle([0, 0, w - 1, 1], fill=shade(rc, 1.2))
    d.rectangle([-1, 4, w, 6], fill=shade(rc, 0.6))
    # windows
    cols, rows = windows
    if cols > 0 and rows > 0:
        mw = int(w / (cols + 1))
        avail_h = h - 34
        mh = max(10, int(avail_h / max(1, rows)))
        for r in range(rows):
            for c in range(cols):
                x = int((c + 0.5) * (w / cols)) - 7
                y = 12 + r * mh
                if y + 14 > h - 22:
                    continue
                lit = rnd.random() < 0.45
                wc = win_col if not lit else WINDOW_LIT
                d.rectangle([x - 1, y - 1, x + 15, y + 13], fill=shade(wall, 0.72))
                d.rectangle([x, y, x + 14, y + 12], fill=wc)
                d.rectangle([x, y, x + 6, y + 5], fill=shade(wc, 1.22))
                d.line([(x, y + 6), (x + 14, y + 6)], fill=shade(wall, 0.8))
                d.line([(x + 7, y), (x + 7, y + 12)], fill=shade(wall, 0.8))
                if rnd.random() < 0.25:
                    d.rectangle([x, y + 7, x + 14, y + 12], fill=shade(wc, 0.75))
    # ground floor storefront
    gy = h - 30
    if door:
        d.rectangle([0, gy, w - 1, h - 1], fill=shade(wall, 0.86))
        # big window
        d.rectangle([4, gy + 4, w - 30, h - 6], fill=shade(wall, 0.6))
        d.rectangle([6, gy + 6, w - 32, h - 8], fill=(126, 180, 200))
        d.polygon([(6, h - 8), (w - 32, gy + 6), (w - 32, gy + 12), (12, h - 8)], fill=(180, 216, 228, 160))
        # door
        dx = w - 26
        d.rectangle([dx, gy + 2, dx + 20, h - 1], fill=shade(door_col, 0.7))
        d.rectangle([dx + 2, gy + 4, dx + 18, h - 1], fill=door_col)
        d.rectangle([dx + 4, gy + 6, dx + 16, gy + 16], fill=(150, 190, 205))
        d.ellipse([dx + 15, gy + 22, dx + 17, gy + 24], fill=(220, 200, 120))
        d.rectangle([0, h - 4, w - 1, h - 1], fill=shade(wall, 0.55))
    if sign:
        sw = min(w - 8, 8 * len(sign) + 12)
        sx = (w - sw) // 2
        sy = gy - 16
        d.rectangle([sx - 2, sy - 2, sx + sw + 2, sy + 14], fill=(38, 34, 44))
        d.rectangle([sx, sy, sx + sw, sy + 12], fill=sign_col)
        # abstract "lettering" blocks so no real font is needed
        rnd2 = random.Random(seed + 77)
        cx = sx + 5
        for ch in sign:
            if ch == " ":
                cx += 5
                continue
            bw = rnd2.choice((4, 5, 6))
            d.rectangle([cx, sy + 3, cx + bw, sy + 9], fill=SIGN_TEXT)
            cx += bw + 2
            if cx > sx + sw - 6:
                break
    return im

# Emissive palette. These exact colours are what gen_emission.py keys on to build the
# glow masks, so they are constants rather than literals buried in the drawing code.
WINDOW_LIT = (250, 226, 150)
SIGN_TEXT = (250, 248, 240)

# Building specs live at module scope so the emission generator can read each building's
# sign colour instead of keeping a second copy that silently drifts out of date.
BUILDING_SPECS = {
    "shop_noodle": dict(w=120, h=150, wall=(186, 92, 74), windows=(3, 3), sign="NOODLE", sign_col=(228, 168, 60), style="brick", seed=2),
    "shop_corner": dict(w=110, h=140, wall=(120, 150, 178), windows=(3, 3), sign="MART", sign_col=(70, 170, 120), style="panel", seed=3),
    "shop_dojo": dict(w=126, h=156, wall=(140, 120, 96), windows=(3, 2), sign="DOJO", sign_col=(190, 60, 60), style="stucco", seed=4),
    "shop_books": dict(w=104, h=146, wall=(96, 116, 92), windows=(3, 3), sign="BOOKS", sign_col=(90, 110, 190), style="brick", seed=5),
    "shop_weapon": dict(w=112, h=140, wall=(110, 100, 120), windows=(3, 2), sign="GEAR", sign_col=(200, 130, 60), style="panel", seed=6),
    "shop_laundry": dict(w=130, h=150, wall=(190, 200, 214), windows=(4, 2), sign="WASH", sign_col=(90, 160, 220), style="panel", seed=7),
    "apartment_a": dict(w=100, h=190, wall=(158, 108, 84), windows=(3, 5), door=False, style="brick", seed=8),
    "apartment_b": dict(w=118, h=210, wall=(126, 122, 132), windows=(4, 6), door=False, style="panel", seed=9),
    "apartment_c": dict(w=92, h=170, wall=(172, 148, 110), windows=(3, 4), door=False, style="brick", seed=10),
    "warehouse": dict(w=180, h=140, wall=(122, 128, 134), windows=(5, 1), door=False, style="metal", seed=11),
    "metro_entrance": dict(w=120, h=120, wall=(96, 92, 104), windows=(0, 0), door=True, sign="METRO", sign_col=(60, 130, 200), style="stucco", seed=12),
}


def build_buildings():
    out = ensure("art", "backgrounds")
    for name, kw in BUILDING_SPECS.items():
        im = building(**kw)
        im.save(os.path.join(out, f"{name}.png"))
    return list(BUILDING_SPECS.keys())

def skyline(w=480, h=120, base=(52, 44, 72), far=True, seed=1):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rnd = random.Random(seed)
    x = -10
    while x < w + 10:
        bw = rnd.randint(24, 58)
        bh = rnd.randint(int(h * 0.3), int(h * 0.92))
        c = shade(base, rnd.uniform(0.85, 1.15))
        d.rectangle([x, h - bh, x + bw, h], fill=c)
        if rnd.random() < 0.4:
            d.rectangle([x + bw // 3, h - bh - rnd.randint(6, 16), x + bw // 3 + 6, h - bh], fill=c)
        if not far:
            for wy in range(h - bh + 6, h - 6, 8):
                for wx in range(x + 4, x + bw - 4, 7):
                    if rnd.random() < 0.35:
                        lit = rnd.random() < 0.5
                        d.rectangle([wx, wy, wx + 3, wy + 4], fill=WINDOW_LIT if lit else shade(c, 0.7))
        x += bw + rnd.randint(2, 8)
    return im

def gradient(w, h, top, bottom):
    im = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / max(1, h - 1)
        c = (int(top[0] + (bottom[0] - top[0]) * t), int(top[1] + (bottom[1] - top[1]) * t), int(top[2] + (bottom[2] - top[2]) * t), 255)
        d.line([(0, y), (w, y)], fill=c)
    return im

def build_backgrounds():
    out = ensure("art", "backgrounds")
    skies = {
        "sky_day": ((126, 186, 226), (226, 206, 190)),
        "sky_dusk": ((72, 66, 122), (238, 148, 106)),
        "sky_night": ((22, 20, 46), (60, 48, 88)),
        "sky_alley": ((54, 52, 78), (96, 86, 104)),
        "sky_industrial": ((104, 96, 110), (196, 158, 128)),
    }
    for name, (t, b) in skies.items():
        gradient(480, 200, t, b).save(os.path.join(out, f"{name}.png"))
    skyline(480, 110, (58, 50, 84), far=True, seed=1).save(os.path.join(out, "skyline_far.png"))
    skyline(480, 130, (44, 38, 64), far=False, seed=2).save(os.path.join(out, "skyline_near.png"))
    skyline(480, 100, (48, 44, 52), far=False, seed=3).save(os.path.join(out, "skyline_industrial.png"))
    # water band for the riverside area
    im = Image.new("RGBA", (480, 60), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 479, 59], fill=(58, 92, 128))
    rnd = random.Random(4)
    for i in range(220):
        x = rnd.randint(0, 479); y = rnd.randint(0, 59)
        w2 = rnd.randint(3, 12)
        d.line([(x, y), (x + w2, y)], fill=shade((58, 92, 128), rnd.uniform(1.05, 1.35)))
    im.save(os.path.join(out, "river.png"))
    # metro platform wall: tiled, with a tunnel mouth and strip lighting
    im = Image.new("RGBA", (480, 220), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 479, 219], fill=(74, 82, 98))
    for y in range(0, 220, 14):
        for x in range(0, 480, 22):
            off = 11 if (y // 14) % 2 else 0
            c = (188, 196, 206) if ((x + y) // 14) % 5 else (150, 170, 196)
            d.rectangle([x + off, y, x + off + 20, y + 12], fill=c)
            d.line([(x + off, y), (x + off + 20, y)], fill=shade(c, 1.12))
    d.rectangle([0, 0, 479, 10], fill=(44, 50, 64))
    for x in range(20, 480, 96):
        d.rectangle([x, 2, x + 52, 7], fill=(250, 244, 208))
    for x in (120, 330):
        d.ellipse([x, 60, x + 120, 220], fill=(26, 30, 42))
        d.ellipse([x + 10, 70, x + 110, 220], fill=(14, 16, 24))
    noise(im, 5, 71).save(os.path.join(out, "metro_wall.png"))

    # rooftop backdrop: sky plus the tops of neighbouring blocks
    im = gradient(480, 200, (58, 52, 96), (226, 140, 110))
    sky_line = skyline(480, 120, (40, 34, 58), far=False, seed=21)
    im.alpha_composite(sky_line, (0, 80))
    im.save(os.path.join(out, "rooftop_sky.png"))

    # interior wall
    im = Image.new("RGBA", (480, 200), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 479, 199], fill=(84, 78, 96))
    for x in range(0, 480, 40):
        d.line([(x, 0), (x, 199)], fill=(74, 68, 86))
    d.rectangle([0, 0, 479, 8], fill=(64, 58, 76))
    noise(im, 6, 5).save(os.path.join(out, "interior_wall.png"))
    # laundromat interior wall (boss room)
    im = Image.new("RGBA", (480, 200), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 479, 199], fill=(196, 206, 218))
    for x in range(0, 480, 16):
        for y in range(0, 200, 16):
            c = (206, 214, 226) if (x // 16 + y // 16) % 2 == 0 else (186, 196, 210)
            d.rectangle([x, y, x + 15, y + 15], fill=c)
    for i in range(6):
        x = 20 + i * 78
        d.rectangle([x, 120, x + 56, 196], fill=(226, 230, 236))
        d.rectangle([x, 120, x + 56, 128], fill=(200, 206, 214))
        d.ellipse([x + 12, 138, x + 44, 172], fill=(90, 100, 116))
        d.ellipse([x + 16, 142, x + 40, 168], fill=(140, 170, 200))
    noise(im, 4, 6).save(os.path.join(out, "laundromat_wall.png"))
    return True

# =====================================================================
# UI
# =====================================================================
def ui_panel(w=64, h=64, fill=(38, 32, 52), border=(120, 106, 150), corner=8):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, w - 1, h - 1], fill=border)
    d.rectangle([2, 2, w - 3, h - 3], fill=shade(border, 0.55))
    d.rectangle([3, 3, w - 4, h - 4], fill=fill)
    d.line([(3, 3), (w - 4, 3)], fill=shade(fill, 1.35))
    d.line([(3, 3), (3, h - 4)], fill=shade(fill, 1.2))
    d.line([(3, h - 4), (w - 4, h - 4)], fill=shade(fill, 0.7))
    return im

def ui_bar(w=64, h=10, fill=(220, 60, 60)):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, w - 1, h - 1], fill=fill)
    d.rectangle([0, 0, w - 1, max(0, h // 3 - 1)], fill=shade(fill, 1.28))
    d.rectangle([0, h - max(1, h // 3), w - 1, h - 1], fill=shade(fill, 0.75))
    return im

def ui_button(size=64, col=(230, 90, 90), label=None):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    r = size // 2 - 1
    c = size / 2
    d.ellipse([c - r, c - r, c + r, c + r], fill=(20, 16, 28, 190))
    d.ellipse([c - r + 2, c - r + 2, c + r - 2, c + r - 2], fill=(col[0], col[1], col[2], 215))
    d.ellipse([c - r + 4, c - r + 4, c + r * 0.2, c + r * 0.1], fill=(255, 255, 255, 60))
    if label:
        # simple pictographs
        if label == "fist":
            d.rounded_rectangle([c - 10, c - 8, c + 8, c + 8], 4, fill=(250, 236, 220))
            for i in range(3):
                d.line([(c - 6 + i * 6, c - 6), (c - 6 + i * 6, c + 2)], fill=(200, 170, 150))
            d.rounded_rectangle([c + 6, c - 4, c + 12, c + 6], 3, fill=(250, 236, 220))
        elif label == "boot":
            d.polygon([(c - 8, c - 10), (c + 1, c - 10), (c + 1, c + 3), (c + 11, c + 3), (c + 11, c + 9), (c - 8, c + 9)], fill=(250, 236, 220))
        elif label == "arrow_up":
            d.polygon([(c, c - 10), (c + 9, c + 2), (c - 9, c + 2)], fill=(250, 250, 250))
            d.rectangle([c - 3, c + 2, c + 3, c + 9], fill=(250, 250, 250))
        elif label == "hand":
            d.rounded_rectangle([c - 8, c - 4, c + 8, c + 8], 4, fill=(250, 236, 220))
            for i in range(4):
                d.rounded_rectangle([c - 8 + i * 4, c - 11, c - 5 + i * 4, c - 2], 2, fill=(250, 236, 220))
        elif label == "star":
            st = fx_star(int(size * 0.6), (255, 240, 170))
            im.alpha_composite(st, (int(c - st.width / 2), int(c - st.height / 2)))
        elif label == "shield":
            d.polygon([(c, c - 11), (c + 9, c - 7), (c + 9, c + 2), (c, c + 11), (c - 9, c + 2), (c - 9, c - 7)],
                      fill=(238, 236, 228))
            d.polygon([(c, c - 8), (c + 6, c - 5), (c + 6, c + 1), (c, c + 8), (c - 6, c + 1), (c - 6, c - 5)],
                      fill=(150, 172, 205))
            d.line([(c, c - 8), (c, c + 8)], fill=(238, 236, 228))
        elif label == "pause":
            d.rectangle([c - 6, c - 8, c - 2, c + 8], fill=(250, 250, 250))
            d.rectangle([c + 2, c - 8, c + 6, c + 8], fill=(250, 250, 250))
    return im

def ui_joystick():
    base = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    d = ImageDraw.Draw(base)
    d.ellipse([0, 0, 95, 95], fill=(20, 16, 30, 120))
    d.ellipse([4, 4, 91, 91], fill=(60, 52, 80, 110))
    d.ellipse([8, 8, 87, 87], fill=(30, 24, 44, 90))
    for a in range(0, 360, 90):
        x = 48 + math.cos(math.radians(a)) * 34
        y = 48 + math.sin(math.radians(a)) * 34
        d.polygon([(x + math.cos(math.radians(a)) * 6, y + math.sin(math.radians(a)) * 6),
                   (x + math.cos(math.radians(a + 130)) * 6, y + math.sin(math.radians(a + 130)) * 6),
                   (x + math.cos(math.radians(a - 130)) * 6, y + math.sin(math.radians(a - 130)) * 6)],
                  fill=(180, 170, 210, 120))
    knob = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d2 = ImageDraw.Draw(knob)
    d2.ellipse([0, 0, 47, 47], fill=(24, 20, 34, 200))
    d2.ellipse([3, 3, 44, 44], fill=(196, 190, 220, 230))
    d2.ellipse([8, 7, 28, 24], fill=(240, 238, 250, 200))
    return base, knob

def ui_icons():
    out = {}
    # coin icon
    out["icon_money"] = coin(12)
    # heart
    im = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(6, 11), (0, 5), (0, 3), (2, 1), (6, 3), (10, 1), (12, 3), (12, 5)], fill=(226, 68, 78))
    d.polygon([(3, 3), (5, 4), (3, 6), (1, 4)], fill=(250, 140, 150))
    out["icon_hp"] = im
    # bolt
    im = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(7, 0), (2, 7), (5, 7), (4, 12), (10, 4), (6, 4)], fill=(250, 210, 80))
    out["icon_energy"] = im
    # star (xp)
    out["icon_xp"] = fx_star(12, (140, 200, 250))
    # fist
    im = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([1, 3, 9, 10], 2, fill=(244, 202, 160))
    d.rounded_rectangle([8, 5, 11, 9], 1, fill=(244, 202, 160))
    out["icon_move"] = outline_alpha(im)
    # scroll (quest)
    im = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([2, 1, 9, 10], fill=(238, 226, 190))
    d.rectangle([2, 1, 9, 2], fill=(200, 186, 150))
    for y in (4, 6, 8):
        d.line([(4, y), (8, y)], fill=(140, 120, 100))
    out["icon_quest"] = outline_alpha(im)
    return out

def build_ui():
    out = ensure("art", "ui")
    ui_panel(48, 48).save(os.path.join(out, "panel.png"))
    ui_panel(48, 48, fill=(24, 20, 34), border=(90, 80, 120)).save(os.path.join(out, "panel_dark.png"))
    ui_panel(48, 48, fill=(52, 40, 70), border=(190, 160, 220)).save(os.path.join(out, "panel_focus.png"))
    ui_bar(32, 8, (222, 62, 62)).save(os.path.join(out, "bar_hp.png"))
    ui_bar(32, 8, (240, 196, 70)).save(os.path.join(out, "bar_energy.png"))
    ui_bar(32, 8, (110, 190, 240)).save(os.path.join(out, "bar_xp.png"))
    ui_bar(32, 8, (200, 80, 220)).save(os.path.join(out, "bar_special.png"))
    ui_bar(32, 8, (60, 52, 74)).save(os.path.join(out, "bar_back.png"))
    ui_bar(32, 8, (190, 50, 60)).save(os.path.join(out, "bar_boss.png"))
    for name, label, col in (("btn_light", "fist", (230, 90, 90)), ("btn_heavy", "boot", (230, 150, 60)),
                             ("btn_jump", "arrow_up", (90, 180, 230)), ("btn_grab", "hand", (150, 200, 100)),
                             ("btn_special", "star", (200, 110, 230)),
                             ("btn_guard", "shield", (90, 150, 205)),
                             ("btn_pause", "pause", (120, 116, 140))):
        ui_button(72, col, label).save(os.path.join(out, f"{name}.png"))
    base, knob = ui_joystick()
    base.save(os.path.join(out, "joy_base.png"))
    knob.save(os.path.join(out, "joy_knob.png"))
    for k, v in ui_icons().items():
        v.save(os.path.join(out, f"{k}.png"))
    # title logo
    logo = Image.new("RGBA", (300, 96), (0, 0, 0, 0))
    d = ImageDraw.Draw(logo)
    # stylised skyline crown over a plate; text is rendered by the engine font
    d.rectangle([0, 44, 299, 92], fill=(26, 20, 38))
    d.rectangle([3, 47, 296, 89], fill=(214, 62, 72))
    d.rectangle([3, 47, 296, 58], fill=(240, 110, 100))
    d.rectangle([3, 82, 296, 89], fill=(160, 36, 50))
    rnd = random.Random(12)
    x = 0
    while x < 300:
        bw = rnd.randint(14, 30); bh = rnd.randint(12, 42)
        d.rectangle([x, 44 - bh, x + bw, 44], fill=(40, 32, 58))
        for wy in range(44 - bh + 4, 42, 7):
            for wx in range(x + 3, x + bw - 3, 6):
                if rnd.random() < 0.4:
                    d.rectangle([wx, wy, wx + 2, wy + 3], fill=(250, 216, 130))
        x += bw + rnd.randint(1, 5)
    logo.save(os.path.join(out, "logo_plate.png"))
    return True

def build_fx():
    out = ensure("art", "fx")
    write_strip(fx_spark(20, (255, 220, 120), 6, 1), os.path.join(out, "spark_small.png"))
    write_strip(fx_spark(30, (255, 180, 90), 8, 2), os.path.join(out, "spark_big.png"))
    write_strip(fx_spark(26, (170, 220, 255), 7, 3), os.path.join(out, "spark_weapon.png"))
    write_strip(fx_spark(36, (230, 150, 255), 10, 4), os.path.join(out, "spark_special.png"))
    write_strip(fx_dust(18), os.path.join(out, "dust.png"))
    write_strip(fx_impact_ring(28), os.path.join(out, "ring.png"))
    write_strip(fx_impact_ring(40, (200, 160, 255)), os.path.join(out, "ring_special.png"))
    fx_shadow(22, 8).save(os.path.join(out, "shadow.png"))
    fx_shadow(34, 11).save(os.path.join(out, "shadow_big.png"))
    fx_star(12).save(os.path.join(out, "star.png"))
    fx_sweat(8).save(os.path.join(out, "sweat.png"))
    # exclamation bubble for enemy alert
    im = Image.new("RGBA", (14, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, 13, 12], fill=(250, 250, 245))
    d.polygon([(5, 11), (9, 11), (6, 16)], fill=(250, 250, 245))
    d.rectangle([6, 3, 7, 7], fill=(220, 60, 60))
    d.rectangle([6, 8, 7, 9], fill=(220, 60, 60))
    outline_alpha(im).save(os.path.join(out, "alert.png"))
    return True

def build_props():
    out = ensure("art", "props")
    for name, fn in PROPS.items():
        fn().save(os.path.join(out, f"{name}.png"))
    return list(PROPS.keys())

def build_weapons():
    out = ensure("art", "weapons")
    for name, fn in WEAPONS_ART.items():
        fn().save(os.path.join(out, f"{name}.png"))
    return list(WEAPONS_ART.keys())

def build_items():
    out = ensure("art", "ui", "items")
    coin(10).save(os.path.join(out, "coin_small.png"))
    coin(14, (250, 220, 110)).save(os.path.join(out, "coin_big.png"))
    bill().save(os.path.join(out, "bill.png"))
    foods = {
        "burger": ("burger", (200, 100, 60), (240, 200, 120)),
        "noodles": ("noodles", (220, 90, 70), (240, 220, 180)),
        "drink": ("drink", (110, 180, 230), (250, 250, 250)),
        "donut": ("donut", (230, 120, 170), (250, 240, 120)),
        "skewer": ("skewer", (180, 90, 60), (140, 190, 90)),
        "sandwich": ("sandwich", (230, 200, 140), (200, 90, 80)),
        "icecream": ("icecream", (240, 210, 230), (220, 90, 120)),
        "soup": ("soup", (220, 140, 70), (250, 250, 250)),
        "pizza": ("pizza", (220, 130, 80), (190, 60, 60)),
        "candy": ("candy", (240, 100, 140), (250, 220, 90)),
        "coffee": ("coffee", (160, 100, 60), (240, 240, 235)),
        "book_red": ("book", (190, 70, 70), None),
        "book_blue": ("book", (70, 110, 200), None),
        "book_green": ("book", (80, 160, 100), None),
        "book_gold": ("book", (200, 170, 70), None),
    }
    for name, (kind, c1, c2) in foods.items():
        food_icon(kind, c1, c2 or c1).save(os.path.join(out, f"{name}.png"))
    # key items
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([2, 4, 13, 14], 2, fill=(150, 100, 60))
    d.rectangle([5, 1, 10, 5], fill=(120, 80, 45))
    d.rectangle([6, 8, 9, 11], fill=(220, 190, 120))
    outline_alpha(im).save(os.path.join(out, "backpack.png"))
    prop_flyer().resize((16, 16), Image.NEAREST).save(os.path.join(out, "flyer.png"))
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([1, 4, 14, 12], fill=(240, 235, 220))
    d.polygon([(1, 4), (8, 9), (14, 4)], fill=(215, 210, 195))
    d.rectangle([9, 8, 13, 12], fill=(200, 60, 60))
    outline_alpha(im).save(os.path.join(out, "letter.png"))
    return True

def main():
    ensure("art", "props"); ensure("art", "weapons"); ensure("art", "tilesets"); ensure("art", "fx")
    p = build_props(); print(f"props: {len(p)}")
    w = build_weapons(); print(f"weapons: {len(w)}")
    build_items(); print("items ok")
    build_fx(); print("fx ok")
    build_ui(); print("ui ok")
    t = build_tileset(); print(f"tiles: {len(t)}")
    b = build_buildings(); print(f"buildings: {len(b)}")
    build_backgrounds(); print("backgrounds ok")

if __name__ == "__main__":
    main()

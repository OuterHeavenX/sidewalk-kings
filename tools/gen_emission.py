#!/usr/bin/env python3
"""
Sidewalk Kings - emission masks and light textures.

Bloom in Godot works on the finished frame, thresholded by brightness. With HDR 2D on and
the threshold at 1.0, ordinary art clamps at 1.0 and cannot bloom no matter how pale it is.
Only sprites pushed ABOVE 1.0 bleed. That is what these masks are for: a per-asset image
holding just the pixels that emit light, drawn again on top of the art at a gain above 1.0.

Hand-painting glow masks across the whole art set would be miserable. Deriving them from
the generated art is a loop, which is the entire reason this pipeline is generated.

Two outputs:
  assets/art/emission/<name>_e.png  - the emissive pixels of an existing sprite
  assets/art/light/<name>.png       - soft radial falloffs used as PointLight2D textures

Run from the project root, after gen_world.py:  python tools/gen_emission.py
"""
import os
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_world as W

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "assets", "art")
OUT_EMIT = os.path.join(ART, "emission")
OUT_LIGHT = os.path.join(ART, "light")

# Props run their pixels through noise() as a final step, which jitters every channel by a
# few levels. Exact colour equality would therefore match nothing, so keys match within a
# small radius. Unrelated colours in this palette are far further apart than this.
TOLERANCE = 14


def _keys_for_building(name, spec):
    """A building glows from its lit windows and its sign, and from nothing else.

    Keys are (colour, required). Some tones are drawn on a dice roll: the dim lower pane
    appears on a quarter of windows, so a building can legitimately have none. Those must
    not fail the build, while a missing sign colour still should.
    """
    keys = []
    cols, rows = spec.get("windows", (0, 0))
    if cols > 0 and rows > 0:
        keys.append((W.WINDOW_LIT, True))
        keys.append((W.shade(W.WINDOW_LIT, 1.22)[:3], True))
        keys.append((W.shade(W.WINDOW_LIT, 0.75)[:3], False))
    if spec.get("sign"):
        keys.append((spec["sign_col"], True))
        keys.append((W.SIGN_TEXT, True))
    return keys


# What glows, and how hard. Gain is applied in the engine as a modulate multiplier, so 3.0
# means "three times white", which is comfortably over the bloom threshold.
PROP_EMISSION = {
    "streetlight": (2.9, [((250, 240, 190), True), ((255, 255, 235), True)]),
    "ticket_machine": (1.45, [((120, 200, 190), True)]),
    "metro_sign": (1.7, [((58, 118, 190), True), ((238, 240, 246), True)]),
    "vending": (1.5, [((120, 190, 230), True), ((240, 120, 60), True)]),
    "phonebooth": (1.4, [((150, 190, 205), True)]),
}

# The near skyline has lit windows in it; the far one is deliberately unlit haze.
BACKDROP_EMISSION = {
    "skyline_near": (1.35, [(W.WINDOW_LIT, True)]),
}


def extract(src_path, keys, tol=TOLERANCE):
    """Keep only pixels near one of the key colours. Everything else becomes transparent."""
    im = Image.open(src_path).convert("RGBA")
    px = im.load()
    w, h = im.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    hits = {k: 0 for k, _req in keys}
    t2 = tol * tol
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 128:
                continue
            for k, _req in keys:
                dr, dg, db = r - k[0], g - k[1], b - k[2]
                if dr * dr + dg * dg + db * db <= t2:
                    op[x, y] = (r, g, b, 255)
                    hits[k] += 1
                    break
    return out, hits


def radial(size, falloff=2.0, inner=0.0):
    """A soft round falloff, used as a PointLight2D texture and as a lamp halo."""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    p = im.load()
    c = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            d = (((x - c) ** 2 + (y - c) ** 2) ** 0.5) / c
            if d >= 1.0:
                continue
            v = 1.0 if d <= inner else (1.0 - (d - inner) / max(1e-5, 1.0 - inner))
            a = int(255 * (v ** falloff))
            p[x, y] = (255, 255, 255, max(0, min(255, a)))
    return im


def main():
    os.makedirs(OUT_EMIT, exist_ok=True)
    os.makedirs(OUT_LIGHT, exist_ok=True)
    problems = []
    written = 0

    def do(rel_src, name, gain, keys):
        nonlocal written
        src = os.path.join(ART, rel_src)
        if not os.path.exists(src):
            problems.append("missing source art: %s" % rel_src)
            return
        img, hits = extract(src, keys)
        # A key that matches nothing means the art changed underneath this table and the
        # asset would silently stop glowing. That is exactly the kind of quiet failure
        # worth breaking the build over.
        required = {k for k, req in keys if req}
        for k, n in hits.items():
            if n == 0 and k in required:
                problems.append("%s: required colour %s matched no pixels" % (name, k))
        if img.getbbox() is None:
            problems.append("%s: mask is empty" % name)
            return
        img.save(os.path.join(OUT_EMIT, "%s_e.png" % name))
        written += 1
        print("  %-18s %4d px   gain %.1f" % (name, sum(hits.values()), gain))

    print("emission masks:")
    for name, (gain, keys) in PROP_EMISSION.items():
        do(os.path.join("props", "%s.png" % name), name, gain, keys)
    for name, (gain, keys) in BACKDROP_EMISSION.items():
        do(os.path.join("backgrounds", "%s.png" % name), name, gain, keys)
    for name, spec in W.BUILDING_SPECS.items():
        if spec.get("windows", (0, 0))[0] == 0 and not spec.get("sign"):
            continue
        do(os.path.join("backgrounds", "%s.png" % name), name, 1.4, _keys_for_building(name, spec))

    print("light textures:")
    for name, size, falloff, inner in [
        ("lamp", 128, 2.2, 0.04),
        ("wide", 192, 1.7, 0.02),
        ("tight", 64, 2.6, 0.08),
        ("halo", 48, 2.8, 0.10),
    ]:
        radial(size, falloff, inner).save(os.path.join(OUT_LIGHT, "%s.png" % name))
        print("  %-18s %dpx" % (name, size))

    if problems:
        print("\nEMISSION PROBLEMS:")
        for p in problems:
            print("  - " + p)
        raise SystemExit("gen_emission failed: %d problem(s)" % len(problems))
    print("\nemission: %d masks, 4 light textures" % written)


# The gain table is read by the engine, so it is written out rather than duplicated there.
def gains():
    g = {}
    for name, (gain, _k) in PROP_EMISSION.items():
        g[name] = gain
    for name, (gain, _k) in BACKDROP_EMISSION.items():
        g[name] = gain
    for name, spec in W.BUILDING_SPECS.items():
        if spec.get("windows", (0, 0))[0] == 0 and not spec.get("sign"):
            continue
        g[name] = 1.4
    return g


if __name__ == "__main__":
    main()
    import json
    with open(os.path.join(OUT_EMIT, "gains.json"), "w", newline="\n") as f:
        json.dump(gains(), f, indent=1, sort_keys=True)
    print("wrote emission/gains.json")

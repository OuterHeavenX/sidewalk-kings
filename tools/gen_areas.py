#!/usr/bin/env python3
"""
Sidewalk Kings - area layout generator.

Each playable area is a JSON layout in res://data/areas/. Area.gd reads it and builds the
street at runtime: parallax, ground tiles, buildings, props, weapons, NPCs, doors, spawns
and encounter triggers. Adding a neighbourhood means adding a layout here.

Run from the project root:  python tools/gen_areas.py
"""
import os, json, random, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_world as W

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "areas")
os.makedirs(OUT, exist_ok=True)

BG = "res://assets/art/backgrounds/"
PROP = "res://assets/art/props/"

# Vertical layout, in world pixels. y grows downward and doubles as lane depth:
# a smaller y is further into the screen, which is what drives Y-sorting.
#
#   ROAD_TOP  -46 ┬ road (parked cars, back edge of the scene)
#   BUILD_BASE -46 ┼ buildings stand here, on the road's far edge
#   SIDEWALK   18 ┼ sidewalk tiles start
#   LANE_MIN   34 ┼ back of the walkable lane
#   LANE_MAX   74 ┼ front of the walkable lane
#             130 ┴ sidewalk tiles end
LANE_MIN = 34.0
LANE_MAX = 74.0
SIDEWALK_TOP = 18.0
SIDEWALK_ROWS = 9
CURB_TOP = 2.0
ROAD_TOP = -46.0
# Buildings stand on the FAR edge of the road, so their base line is the road's top edge.
# It used to be the curb line, 48px nearer, which meant the road was drawn over the bottom
# of every facade and hid the shopfronts.
BUILD_BASE = ROAD_TOP

# Awnings, graffiti, vents and signs are positioned by eye against the facades. Correcting
# the building placement moved every facade down by 8px, so decorations hang from their own
# line: anchoring them to BUILD_BASE would have lifted them 48px off the buildings.
DECO_BASE = 10.0
CAMERA_Y = -12.0      # camera centre; shows roughly y -147..123 at 480x270
# The walkable ground plane, which is the curb line and has nothing to do with where
# buildings are drawn. These were the same constant, so moving the buildings would have
# silently moved the floor the player stands on.
GROUND_Y = CURB_TOP


def _tex_path(name, base=None):
    """Accept a bare asset name, a folder-relative name, or a full res:// path."""
    if name.startswith("res://"):
        return name if name.endswith(".png") else name + ".png"
    return (base or BG) + name + ".png"


def sky(tex, y=-150.0, scroll=0.05, repeat=3, scale=1.0, modulate=None, z=-90):
    d = {"texture": _tex_path(tex), "y": y, "scroll": scroll, "repeat": repeat, "scale": scale, "z": z}
    if modulate:
        d["modulate"] = modulate
    return d


def scenery(tex, x, y, z=-10, scale=1.0, front=False, flip=False, modulate=None, **kw):
    """A flat decoration. Extra keywords pass straight through to the layout, which is how
    ambient flags such as sway and flicker reach the engine without a signature change
    every time one is added."""
    d = {"texture": _tex_path(tex), "x": x, "y": y, "z": z, "scale": scale}
    d.update(kw)
    if front:
        d["front"] = True
    if flip:
        d["flip"] = True
    if modulate:
        d["modulate"] = modulate
    return d


def ambient(drift=None):
    """Area-level ambient motion. Currently just wind-blown litter."""
    out = {}
    if drift:
        out["drift"] = drift
    return out


def litter(count=7, speed=13.0, colors=None, y_min=None, y_max=None):
    """Paper and leaves crossing the street. Negative speed blows the other way."""
    d = {"count": count, "speed": speed,
         "colors": colors or [[0.82, 0.80, 0.72], [0.68, 0.66, 0.58], [0.74, 0.70, 0.55]]}
    if y_min is not None:
        d["y_min"] = y_min
    if y_max is not None:
        d["y_max"] = y_max
    return d


def prop(pid, x, y=None, **kw):
    d = {"id": pid, "x": x, "y": LANE_MAX + 2 if y is None else y}
    d.update(kw)
    return d


def fill(color, y, height=420, x=None, x2=None, z=-26):
    """A flat backing band behind the tiles, so tall screens never show empty space."""
    d = {"color": list(color), "y": y, "height": height, "z": z}
    if x is not None:
        d["x"] = x
    if x2 is not None:
        d["x2"] = x2
    return d


def ground(tile, y, height=1, x=None, x2=None, alt=None, z=-20):
    d = {"tile": tile, "y": y, "height": height, "z": z}
    if x is not None:
        d["x"] = x
    if x2 is not None:
        d["x2"] = x2
    if alt:
        d["alt"] = alt
    return d


def light(x, y, color=(1.0, 0.86, 0.6), energy=1.15, scale=1.0, texture="lamp"):
    """One light pool. y is lane depth, same as everything else in a layout."""
    return {"x": x, "y": y, "color": list(color), "energy": energy,
            "scale": scale, "texture": texture}


def lighting(ambient, lights, glow=True):
    """Ambient tint is the time of day; the lights are what argues with it."""
    return {"ambient": list(ambient), "glow": glow, "lights": lights}


def lamp_lights(width, spacing=170, start=60, color=(1.0, 0.86, 0.58), energy=1.15, scale=2.0):
    """A light pool under each street lamp.

    Mirrors lamp_row exactly, so a lamp and its pool cannot drift apart. Hand-placing
    these was the obvious alternative and would have gone stale the first time a street
    changed its lamp spacing.
    """
    out = []
    x = start
    while x < width - 40:
        out.append(light(x, 34.0, color, energy, scale))
        x += spacing
    return out


def build(area_id, width, layout):
    layout.setdefault("lane_min", LANE_MIN)
    layout.setdefault("lane_max", LANE_MAX)
    layout.setdefault("walk_min_x", 20.0)
    layout.setdefault("walk_max_x", width - 20.0)
    layout.setdefault("ground_y", GROUND_Y)
    layout.setdefault("camera_y", CAMERA_Y)
    with open(os.path.join(OUT, area_id + ".json"), "w", newline="\n") as f:
        json.dump(layout, f, indent=1)
    print("  %s (%dpx wide)" % (area_id, width))


def street_ground(width, main="sidewalk_a", alt="sidewalk_b", road="asphalt_a"):
    """Standard street: road at the back, a curb line, then the walkable sidewalk."""
    return [
        fill((0.60, 0.59, 0.57), SIDEWALK_TOP, 460, -40, width + 40),
        ground(road, ROAD_TOP, 3, -40, width + 40, alt="asphalt_b", z=-24),
        ground("curb", CURB_TOP, 1, -40, width + 40, z=-23),
        ground(main, SIDEWALK_TOP, SIDEWALK_ROWS, -40, width + 40, alt=alt, z=-22),
    ]


def building(tex, x, height=None, z=-30, **kw):
    """Place a building so its base sits exactly on the road's far edge.

    The height was previously passed in by hand and did not match the art: every facade
    was placed about eight pixels short, leaving a gap with the distant skyline showing
    through underneath, which is what made the buildings look like they were floating.
    The real height comes from the same spec table gen_world draws them from, so the two
    cannot drift apart again. The argument is ignored and kept only so existing layouts
    read unchanged.
    """
    spec = W.BUILDING_SPECS.get(tex)
    if spec is None:
        raise SystemExit("gen_areas: unknown building %r; add it to gen_world.BUILDING_SPECS" % tex)
    return scenery(tex, x, BUILD_BASE - spec["h"], z=z, **kw)


def lamp_row(width, spacing=170, start=60):
    """Street lights stand on the back edge of the sidewalk."""
    out = []
    x = start
    while x < width - 40:
        # One lamp in four is on the way out. A row of identically steady lamps reads as
        # wallpaper; one that stutters makes the whole street feel maintained by nobody.
        failing = (len(out) % 4 == 3)
        out.append(scenery(PROP + "streetlight", x, SIDEWALK_TOP - 96.0, z=-8,
                           flicker=0.22 if failing else 0.05,
                           flicker_speed=5.5 if failing else 1.6))
        x += spacing
    return out


# ===========================================================================
# AREA 1 - FERRY ROW : movement, first fight, money, NPCs
# ===========================================================================
W1 = 1500
ferry = {
    "parallax": [
        sky("sky_dusk", -430.0, 0.02, 4, 2.2, z=-95),
        sky("river", 20.0, 0.12, 4, 1.0, [0.8, 0.85, 1.0], z=-92),
        sky("skyline_far", -110.0, 0.25, 4, 1.0, [0.62, 0.6, 0.82], z=-90),
        sky("skyline_near", -80.0, 0.5, 4, 1.0, [0.78, 0.74, 0.92], z=-85),
    ],
    "ground": street_ground(W1),
    "scenery": (
        [
            building("apartment_a", 60, 246, z=-30),
            building("shop_corner", 210, 196, z=-30),
            building("apartment_c", 350, 226, z=-30),
            building("apartment_b", 470, 266, z=-30),
            building("shop_noodle", 640, 206, z=-30),
            building("apartment_a", 790, 246, z=-30, flip=True),
            building("apartment_c", 930, 226, z=-30),
            building("apartment_b", 1060, 266, z=-30, flip=True),
            building("shop_corner", 1230, 196, z=-30, flip=True),
            building("apartment_a", 1370, 246, z=-30),
            scenery(PROP + "awning_blue", 214, DECO_BASE - 62, z=-28, sway=1, sway_speed=1.0),
            scenery(PROP + "awning_red", 646, DECO_BASE - 70, z=-28, sway=1, sway_speed=0.9),
            scenery(PROP + "graffiti_a", 420, DECO_BASE - 60, z=-27),
            scenery(PROP + "graffiti_c", 1130, DECO_BASE - 56, z=-27),
            scenery(PROP + "car_blue", 300, CURB_TOP - 38, z=-21),
            scenery(PROP + "car_red", 880, CURB_TOP - 38, z=-21),
            scenery(PROP + "fence", 1420, CURB_TOP - 38, z=-21),
        ]
        + lamp_row(W1)
    ),
    "props": [
        prop("hydrant", 120),
        prop("bench", 250, LANE_MIN - 2, solid=False),
        prop("trashcan", 330, breakable=True, hp=10, money=12, contains="candy_bar"),
        prop("sewer_grate", 400, LANE_MAX - 6),
        prop("bin_bags", 470),
        prop("trashcan", 560, breakable=True, hp=10, money=9),
        prop("phonebooth", 700, LANE_MIN - 4, solid=True),
        prop("bollard", 760),
        prop("hydrant", 850),
        prop("bench", 960, LANE_MIN - 2),
        prop("trashcan", 1050, breakable=True, hp=10, money=14, contains="rice_ball"),
        prop("cone", 1120),
        prop("puddle", 1180, LANE_MAX - 4),
        prop("vending", 1250, LANE_MIN - 6, solid=True, searchable=True,
             dialogue="vending_broken", prompt="Use machine"),
        prop("bin_bags", 1330),
    ],
    "weapons": [
        {"id": "bottle", "x": 480},
        {"id": "plank", "x": 1010},
    ],
    "npcs": [
        {"id": "dez", "name": "Dez", "character": "dez", "x": 150, "y": LANE_MIN + 4,
         "gives_hints": True,
         "conditional": [
             {"dialogue": "dez_ending", "if_flag": "chapter_3_done"},
             {"dialogue": "dez_took_it", "if_flag": "took_the_form", "if_not_flag": "told_dez_ch3"},
             {"dialogue": "dez_chapter_two", "if_flag": "chapter_2_done", "if_not_flag": "told_dez_ch2"},
             {"dialogue": "dez_metro", "if_flag": "chapter_1_done", "if_not_flag": "metro_open"},
             {"dialogue": "dez_finale", "if_flag": "hideout_cleared"},
             {"dialogue": "dez_alley", "if_flag": "market_cleared"},
             {"dialogue": "dez_pigeons_done", "if_quest": ["q_pigeons", "ready"]},
             {"dialogue": "dez_hub", "if_flag": "knows_premise"},
         ], "dialogue": "intro_ferry"},
        {"id": "old_ferry", "name": "Ferry Man", "character": "old_ferry", "x": 60, "y": LANE_MIN + 2,
         "conditional": [{"dialogue": "old_ferry_done", "if_quest": ["q_hungry", "ready"]}],
         "dialogue": "old_ferry_intro"},
        {"id": "performer", "name": "Street Performer", "character": "performer", "x": 620,
         "y": LANE_MIN + 6, "dialogue": "performer_line", "wander": True},
        {"id": "worker_a", "name": "Dock Worker", "character": "worker", "x": 900,
         "y": LANE_MIN + 3, "dialogue": "worker_line"},
        {"id": "local_a", "name": "Local", "character": "student", "x": 1200,
         "y": LANE_MIN + 5, "dialogue": "auntie_wander", "wander": True},
    ],
    "doors": [
        {"id": "to_market", "to": "lantern_market", "spawn": "from_ferry", "x": W1 - 24,
         "y": LANE_MAX - 16, "label": "Lantern Market", "auto": True, "w": 22, "h": 46},
    ],
    "spawns": [
        {"id": "start", "x": 90, "y": 56},
        {"id": "from_market", "x": W1 - 70, "y": 56},
    ],
    "encounters": [
        {"id": "ferry_tutorial", "x": 380, "width": 60},
        {"id": "ferry_pair", "x": 760, "width": 60},
        {"id": "ferry_squad", "x": 1180, "width": 70},
    ],
    # run_entry_events fires only the first matching entry, so the comic cannot sit
    # alongside the intro dialogue -- it has to contain it.
    "on_enter": [
        {"cutscene": "intro_comic", "if_not_flag": "seen_intro"},
    ],
    "ambient": ambient(drift=litter(count=8, speed=15.0)),
    # Dusk. The sun is gone but the sky has not caught up, so the ambient is still bluish
    # while every lamp on the street has just come on warm. That disagreement is the whole
    # effect: matching them would read as a tint.
    "lighting": lighting(
        (0.56, 0.55, 0.68),
        lamp_lights(W1, 170, 60, (1.0, 0.84, 0.54), 1.15, 2.1)
        + [
            light(214, 26.0, (1.0, 0.78, 0.5), 0.7, 1.3, "tight"),   # awning over the shop
            light(646, 26.0, (1.0, 0.72, 0.46), 0.7, 1.3, "tight"),
            light(-30, 10.0, (0.5, 0.62, 0.9), 0.8, 2.8, "wide"),    # cold light off the river
            light(1250, 24.0, (0.55, 0.9, 0.85), 0.5, 1.0, "tight"), # the vending machine
        ],
    ),
}
build("ferry_row", W1, ferry)

# ===========================================================================
# AREA 2 - LANTERN MARKET : shops, dojo, NPCs, optional fight
# ===========================================================================
W2 = 1600
market = {
    "parallax": [
        sky("sky_day", -430.0, 0.02, 4, 2.2, [0.9, 0.85, 0.95], z=-95),
        sky("skyline_far", -120.0, 0.25, 4, 1.0, [0.66, 0.64, 0.84], z=-90),
        sky("skyline_near", -86.0, 0.5, 4, 1.0, [0.82, 0.78, 0.94], z=-85),
    ],
    "ground": street_ground(W2),
    "scenery": (
        [
            building("apartment_b", 40, 266, z=-30),
            building("shop_noodle", 190, 206, z=-30),
            building("shop_corner", 350, 196, z=-30),
            building("apartment_c", 490, 226, z=-30),
            building("shop_books", 620, 202, z=-30),
            building("apartment_a", 760, 246, z=-30, flip=True),
            building("shop_dojo", 900, 212, z=-30),
            building("apartment_b", 1060, 266, z=-30),
            building("shop_weapon", 1220, 196, z=-30),
            building("apartment_c", 1370, 226, z=-30, flip=True),
            building("apartment_a", 1500, 246, z=-30),
            scenery(PROP + "awning_red", 194, DECO_BASE - 70, z=-28, sway=1, sway_speed=0.9),
            scenery(PROP + "awning_green", 354, DECO_BASE - 66, z=-28, sway=1, sway_speed=1.1),
            scenery(PROP + "awning_blue", 624, DECO_BASE - 66, z=-28, sway=1, sway_speed=1.0),
            scenery(PROP + "awning_green", 1224, DECO_BASE - 62, z=-28, sway=1, sway_speed=1.1),
            scenery(PROP + "graffiti_b", 830, DECO_BASE - 58, z=-27),
            scenery(PROP + "car_yellow", 540, CURB_TOP - 38, z=-21),
            scenery(PROP + "car_red", 1140, CURB_TOP - 38, z=-21),
            scenery("metro_entrance", 1330, DECO_BASE - 120, z=-29),
            scenery(PROP + "metro_sign", 1368, DECO_BASE - 142, z=-27, flicker=0.08, flicker_speed=3.1),
        ]
        + lamp_row(W2, 190, 100)
    ),
    "props": [
        prop("crate", 120, breakable=True, hp=8, money=10),
        prop("crate", 140, LANE_MAX - 8, breakable=True, hp=8, contains="morning_donut"),
        prop("bench", 280, LANE_MIN - 2),
        prop("trashcan", 420, breakable=True, hp=10, money=12, contains="dojo_flyer"),
        prop("bin_bags", 470),
        prop("sign", 560, LANE_MIN - 4),
        prop("hydrant", 700),
        prop("trashcan", 840, breakable=True, hp=10, money=8),
        prop("crate", 980, breakable=True, hp=8, contains="weapon:pipe"),
        prop("vending", 1040, LANE_MIN - 6, solid=True, searchable=True, dialogue="vending_broken"),
        prop("bench", 1160, LANE_MIN - 2),
        prop("cone", 1300),
        prop("trashcan", 1400, breakable=True, hp=10, money=16),
        prop("puddle", 1460, LANE_MAX - 4),
    ],
    "weapons": [
        {"id": "bat", "x": 900, "y": LANE_MAX - 2},
        {"id": "basketball", "x": 640},
    ],
    "npcs": [
        {"id": "auntie_mae", "name": "Auntie Mae", "character": "auntie_mae", "x": 224,
         "y": LANE_MIN + 2, "conditional": [{"dialogue": "mae_shop", "if_flag": "met_mae"}],
         "dialogue": "mae_intro"},
        {"id": "vic", "name": "Vic", "character": "vic", "x": 384, "y": LANE_MIN + 2,
         "conditional": [{"dialogue": "vic_shop", "if_flag": "met_vic"}], "dialogue": "vic_intro"},
        {"id": "marisol", "name": "Marisol", "character": "marisol", "x": 654, "y": LANE_MIN + 2,
         "conditional": [{"dialogue": "marisol_shop", "if_flag": "met_marisol"}],
         "dialogue": "marisol_intro"},
        {"id": "odell", "name": "Odell", "character": "odell", "x": 940, "y": LANE_MIN + 2,
         "conditional": [
             {"dialogue": "odell_flyer_done", "if_quest": ["q_flyer", "ready"]},
             {"dialogue": "odell_shop", "if_flag": "met_odell"},
         ], "dialogue": "odell_intro"},
        {"id": "student", "name": "Student", "character": "student", "x": 1120, "y": LANE_MIN + 6,
         "conditional": [{"dialogue": "student_done", "if_quest": ["q_backpack", "ready"]}],
         "dialogue": "student_intro"},
        {"id": "rumor_kid", "name": "Kid", "character": "rumor_kid", "x": 1320, "y": LANE_MIN + 7,
         "dialogue": "rumor_kid_line", "wander": True},
    ],
    "doors": [
        {"id": "to_ferry", "to": "ferry_row", "spawn": "from_market", "x": 16, "y": LANE_MAX - 16,
         "label": "Ferry Row", "auto": True, "w": 22, "h": 46},
        {"id": "to_alley", "to": "grease_alley", "spawn": "from_market", "x": W2 - 24,
         "y": LANE_MAX - 16, "label": "Grease Alley", "auto": True, "w": 22, "h": 46},
        {"id": "to_metro", "to": "metro_platform", "spawn": "from_market", "x": 1352,
         "y": LANE_MIN - 2, "label": "Metro Line", "required_flag": "metro_open",
         "locked": "Chained shut. Somebody laminated the CLOSED sign, which suggests commitment.",
         "w": 26, "h": 40},
        {"id": "mae_door", "shop": "mae_noodles", "x": 250, "y": LANE_MIN - 2, "label": "Mae's Noodles"},
        {"id": "vic_door", "shop": "vic_corner", "x": 410, "y": LANE_MIN - 2, "label": "Corner Store"},
        {"id": "books_door", "shop": "marisol_books", "x": 680, "y": LANE_MIN - 2, "label": "Bookstore"},
        {"id": "dojo_door", "shop": "odell_dojo", "x": 966, "y": LANE_MIN - 2, "label": "Dojo",
         "required_flag": "met_odell", "locked": "The door's shut. Somebody's inside, though."},
    ],
    "spawns": [
        {"id": "start", "x": 80, "y": 56},
        {"id": "from_ferry", "x": 70, "y": 56},
        {"id": "from_alley", "x": W2 - 70, "y": 56},
        {"id": "from_metro", "x": 1340, "y": 58},
    ],
    "encounters": [
        {"id": "market_shakedown", "x": 760, "width": 70},
        {"id": "market_optional", "x": 1440, "width": 60},
    ],
    "ambient": ambient(drift=litter(count=7, speed=-11.0)),
    # Early evening. Warmer and brighter than Ferry Row because the stalls are still open
    # and every shopfront is throwing light onto the pavement.
    "lighting": lighting(
        (0.66, 0.60, 0.68),
        lamp_lights(W2, 190, 100, (1.0, 0.87, 0.6), 1.05, 2.0)
        + [
            light(250, 24.0, (1.0, 0.76, 0.42), 0.9, 1.5, "tight"),   # Mae's
            light(410, 24.0, (1.0, 0.82, 0.52), 0.8, 1.4, "tight"),   # corner store
            light(680, 24.0, (0.95, 0.85, 0.6), 0.8, 1.4, "tight"),   # bookshop
            light(966, 24.0, (1.0, 0.72, 0.4), 0.9, 1.5, "tight"),    # the dojo
            light(1040, 22.0, (0.55, 0.9, 0.85), 0.5, 1.0, "tight"),  # vending
            light(1352, 22.0, (0.5, 0.68, 1.0), 0.7, 1.4, "tight"),   # the metro entrance
        ],
    ),
}
build("lantern_market", W2, market)

# ===========================================================================
# AREA 3 - GREASE ALLEY : weapons, breakables, hidden item
# ===========================================================================
W3 = 1400
alley = {
    "parallax": [
        sky("sky_alley", -430.0, 0.02, 4, 2.2, z=-95),
        sky("skyline_near", -70.0, 0.35, 4, 1.0, [0.45, 0.42, 0.58], z=-90),
    ],
    "ground": [
        fill((0.26, 0.25, 0.29), SIDEWALK_TOP, 460, -40, W3 + 40),
        ground("concrete", ROAD_TOP, 3, -40, W3 + 40, z=-24),
        ground("curb", CURB_TOP, 1, -40, W3 + 40, z=-23),
        ground("asphalt_a", SIDEWALK_TOP, SIDEWALK_ROWS, -40, W3 + 40, alt="asphalt_b", z=-22),
    ],
    "scenery": (
        [
            building("apartment_b", 0, 276, z=-30, modulate=[0.72, 0.7, 0.86]),
            building("apartment_a", 130, 256, z=-30, modulate=[0.72, 0.7, 0.86]),
            building("apartment_c", 250, 236, z=-30, modulate=[0.7, 0.68, 0.84]),
            building("warehouse", 380, 150, z=-30, modulate=[0.76, 0.74, 0.86]),
            building("apartment_b", 580, 276, z=-30, flip=True, modulate=[0.72, 0.7, 0.86]),
            building("apartment_a", 720, 256, z=-30, modulate=[0.7, 0.68, 0.84]),
            building("warehouse", 860, 150, z=-30, flip=True, modulate=[0.74, 0.72, 0.85]),
            building("apartment_c", 1060, 236, z=-30, modulate=[0.72, 0.7, 0.86]),
            building("apartment_b", 1180, 276, z=-30, modulate=[0.7, 0.68, 0.84]),
            building("apartment_a", 1320, 256, z=-30, flip=True, modulate=[0.72, 0.7, 0.86]),
            scenery(PROP + "graffiti_a", 200, DECO_BASE - 70, z=-27),
            scenery(PROP + "graffiti_b", 520, DECO_BASE - 76, z=-27),
            scenery(PROP + "graffiti_c", 900, DECO_BASE - 68, z=-27),
            scenery(PROP + "graffiti_a", 1200, DECO_BASE - 72, z=-27),
            scenery(PROP + "ac_unit", 340, DECO_BASE - 130, z=-28),
            scenery(PROP + "ac_unit", 980, DECO_BASE - 138, z=-28),
            scenery(PROP + "laundry_line", 640, DECO_BASE - 128, z=-28, sway=2, sway_speed=0.8),
            # The way back up to the roof. It stands on clear wall between two lamps: the
            # door used to sit at x=620, which is exactly where lamp_row puts a
            # streetlight, so a lamp stood in front of a door that had no art of its own.
            # z is -20, not the -26 the rest of the wall dressing uses: the sidewalk face
            # is drawn at -24, so at -26 the bottom half of the ladder was hidden behind it
            # and the escape appeared to stop in mid-air. The whole point is that the ladder
            # comes down to where you are standing.
            scenery(PROP + "fire_escape", 726, DECO_BASE - 140, z=-20),
            scenery(PROP + "fence", 60, CURB_TOP - 38, z=-21),
        ]
        + lamp_row(W3, 240, 140)
    ),
    "props": [
        prop("dumpster", 180, LANE_MIN - 4, solid=True, searchable=True, dialogue="alley_note",
             prompt="Look inside"),
        prop("crate", 260, breakable=True, hp=8, money=14),
        prop("barrel", 320, LANE_MAX - 6, breakable=True, hp=12, contains="weapon:pipe"),
        prop("tire", 400),
        prop("pallet", 460, LANE_MIN - 2),
        prop("crate", 540, breakable=True, hp=8, contains="stolen_backpack"),
        prop("bin_bags", 600),
        prop("barrel", 680, breakable=True, hp=12, money=18),
        prop("pipe_stack", 760, LANE_MIN - 3),
        prop("dumpster", 860, LANE_MIN - 4, solid=True, searchable=True),
        prop("tire", 940, LANE_MAX - 4),
        prop("crate", 1020, breakable=True, hp=8, contains="weapon:chair"),
        prop("puddle", 1080, LANE_MAX - 2),
        prop("barrel", 1160, breakable=True, hp=12, money=22, contains="energy_drink"),
        prop("bin_bags", 1240),
        prop("crate", 1320, breakable=True, hp=8, money=25),
    ],
    "weapons": [
        {"id": "pipe", "x": 300},
        {"id": "plank", "x": 720},
        {"id": "brick", "x": 880},
        {"id": "bat", "x": 1140},
    ],
    "npcs": [
        {"id": "pops", "name": "Pops", "character": "pops", "x": 1000, "y": LANE_MIN + 3,
         "conditional": [
             {"dialogue": "pops_soup", "if_quest": ["q_soup", "ready"]},
             {"dialogue": "pops_shop", "if_flag": "met_pops"},
         ], "dialogue": "pops_intro"},
    ],
    "doors": [
        {"id": "to_market", "to": "lantern_market", "spawn": "from_alley", "x": 16,
         "y": LANE_MAX - 16, "label": "Lantern Market", "auto": True, "w": 22, "h": 46},
        {"id": "to_yard", "to": "rustpile_yard", "spawn": "from_alley", "x": W3 - 24,
         "y": LANE_MAX - 16, "label": "Rustpile Yard", "auto": True, "w": 22, "h": 46},
        {"id": "pops_shop_door", "shop": "pops_gear", "x": 1030, "y": LANE_MIN - 2,
         "label": "Pops' Gear", "required_flag": "met_pops",
         "locked": "Pops hasn't decided if he likes you yet."},
        {"id": "to_roof", "to": "rooftop_route", "spawn": "from_alley", "x": 743,
         "y": LANE_MIN - 2, "label": "Climb the fire escape", "required_flag": "metro_open",
         "locked": "No reason to be up on the roofs yet.",
         "w": 34, "h": 46},
    ],
    "spawns": [
        {"id": "start", "x": 80, "y": 58},
        {"id": "from_market", "x": 70, "y": 58},
        {"id": "from_yard", "x": W3 - 70, "y": 58},
        {"id": "from_roof", "x": 600, "y": 60},
    ],
    "encounters": [
        {"id": "alley_ambush", "x": 420, "width": 70},
        {"id": "alley_boss_fight", "x": 1120, "width": 80},
    ],
    "ambient": ambient(drift=litter(count=9, speed=9.0)),
    # Night in a back alley. Dark, cold, and lit by almost nothing: two working lamps and
    # whatever leaks out of Pops' doorway. The gaps between the pools are the point.
    "lighting": lighting(
        (0.34, 0.36, 0.48),
        lamp_lights(W3, 240, 140, (1.0, 0.8, 0.48), 1.3, 2.2)
        + [
            light(1030, 24.0, (1.0, 0.74, 0.44), 1.0, 1.6, "tight"),  # Pops' Gear
            light(620, 20.0, (0.6, 0.75, 1.0), 0.5, 1.2, "tight"),    # the fire escape
        ],
    ),
}
build("grease_alley", W3, alley)

# ===========================================================================
# AREA 4 - RUSTPILE YARD : big fight, mixed archetypes, hazards
# ===========================================================================
W4 = 1500
yard = {
    "parallax": [
        sky("sky_industrial", -430.0, 0.02, 4, 2.2, z=-95),
        sky("skyline_industrial", -96.0, 0.3, 4, 1.0, [0.6, 0.56, 0.6], z=-90),
        sky("skyline_near", -74.0, 0.55, 4, 1.0, [0.5, 0.47, 0.55], z=-85),
    ],
    "ground": [
        fill((0.43, 0.42, 0.45), SIDEWALK_TOP, 460, -40, W4 + 40),
        ground("dirt", ROAD_TOP, 3, -40, W4 + 40, z=-24),
        ground("curb", CURB_TOP, 1, -40, W4 + 40, z=-23),
        ground("concrete", SIDEWALK_TOP, SIDEWALK_ROWS, -40, W4 + 40, z=-22),
    ],
    "scenery": (
        [
            building("warehouse", 20, 150, z=-30),
            building("warehouse", 240, 150, z=-30, flip=True),
            building("apartment_c", 470, 236, z=-30, modulate=[0.78, 0.74, 0.78]),
            building("warehouse", 600, 150, z=-30),
            building("warehouse", 820, 150, z=-30, flip=True),
            building("apartment_b", 1040, 276, z=-30, modulate=[0.76, 0.72, 0.78]),
            building("warehouse", 1180, 150, z=-30),
            building("shop_laundry", 1400, 206, z=-30),
        ]
        + [scenery(PROP + "fence", x, CURB_TOP - 38, z=-21) for x in range(150, W4, 64) if not (560 < x < 900)]
        + lamp_row(W4, 260, 180)
    ),
    "props": [
        prop("pipe_stack", 120, LANE_MIN - 3),
        prop("barrel", 200, breakable=True, hp=14, money=20),
        prop("tire", 260, LANE_MAX - 4),
        prop("pallet", 330, LANE_MIN - 2),
        prop("crate", 400, breakable=True, hp=10, contains="weapon:plank"),
        prop("barrel", 470, LANE_MAX - 6, breakable=True, hp=14, contains="steel_lunch"),
        prop("pipe_stack", 560, LANE_MIN - 3),
        prop("tire", 640),
        prop("crate", 700, breakable=True, hp=10, money=26),
        prop("dumpster", 800, LANE_MIN - 4, solid=True, searchable=True),
        prop("barrel", 900, breakable=True, hp=14, money=30),
        prop("tire", 980, LANE_MAX - 4),
        prop("pallet", 1060, LANE_MIN - 2),
        prop("crate", 1140, breakable=True, hp=10, contains="weapon:trashcan_weapon"),
        prop("barrel", 1240, breakable=True, hp=14, money=34, contains="hot_soup"),
        prop("pipe_stack", 1330, LANE_MIN - 3),
        prop("locker", 1180, LANE_MIN - 6, solid=True, searchable=True),
    ],
    "weapons": [
        {"id": "pipe", "x": 360},
        {"id": "brick", "x": 620},
        {"id": "chair", "x": 880},
        {"id": "bat", "x": 1200},
        {"id": "trash_lid", "x": 1020},
    ],
    "npcs": [
        {"id": "worker_b", "name": "Yard Worker", "character": "worker", "x": 100,
         "y": LANE_MIN + 4, "dialogue": "worker_line"},
    ],
    "doors": [
        {"id": "to_alley", "to": "grease_alley", "spawn": "from_yard", "x": 16, "y": LANE_MAX - 16,
         "label": "Grease Alley", "auto": True, "w": 22, "h": 46},
        {"id": "to_hideout", "to": "starch_laundromat", "spawn": "start", "x": 1430,
         "y": LANE_MIN - 2, "label": "Starch & Sons",
         "required_flag": "yard_cleared", "locked": "The Rust Rats are still crawling all over the yard."},
    ],
    "spawns": [
        {"id": "start", "x": 80, "y": 58},
        {"id": "from_alley", "x": 70, "y": 58},
        {"id": "from_hideout", "x": 1360, "y": 58},
    ],
    "encounters": [
        {"id": "yard_wave_1", "x": 460, "width": 80},
        {"id": "yard_wave_2", "x": 1080, "width": 90},
    ],
    "ambient": ambient(drift=litter(count=6, speed=17.0)),
    # A yard lit for work rather than for people: a few hard sodium floods, orange enough
    # that everything under them loses its own colour.
    "lighting": lighting(
        (0.40, 0.40, 0.52),
        lamp_lights(W4, 260, 180, (1.0, 0.66, 0.3), 1.5, 2.6)
        + [
            light(120, 20.0, (1.0, 0.62, 0.28), 1.1, 2.2, "wide"),
            light(W4 - 120, 20.0, (1.0, 0.62, 0.28), 1.1, 2.2, "wide"),
        ],
    ),
}
build("rustpile_yard", W4, yard)

# ===========================================================================
# AREA 5 - STARCH & SONS : interior, elites, boss
# ===========================================================================
W5 = 1000
hideout = {
    "parallax": [
        {"texture": _tex_path("laundromat_wall"), "y": -396.0, "scroll": 0.8, "repeat": 5, "scale": 2.0, "z": -90},
    ],
    "ground": [
        fill((0.63, 0.60, 0.55), SIDEWALK_TOP - 16.0, 460, -40, W5 + 40),
        ground("tile_floor", SIDEWALK_TOP - 16.0, SIDEWALK_ROWS + 1, -40, W5 + 40, z=-22),
    ],
    "scenery": [
        scenery(PROP + "locker", 90, DECO_BASE - 108, z=-28),
        scenery(PROP + "locker", 130, DECO_BASE - 108, z=-28),
        scenery(PROP + "ac_unit", 400, DECO_BASE - 150, z=-28),
        scenery(PROP + "sign", 640, DECO_BASE - 118, z=-28),
        scenery(PROP + "locker", 900, DECO_BASE - 108, z=-28),
        scenery(PROP + "locker", 940, DECO_BASE - 108, z=-28),
    ],
    "props": [
        prop("bench", 200, LANE_MIN - 2),
        prop("crate", 300, breakable=True, hp=10, money=24),
        prop("trashcan", 380, breakable=True, hp=10, contains="bandage"),
        prop("bench", 500, LANE_MIN - 2),
        prop("crate", 620, breakable=True, hp=10, contains="weapon:mop"),
        prop("trashcan", 720, breakable=True, hp=10, money=30),
        prop("bench", 840, LANE_MIN - 2),
    ],
    "weapons": [
        {"id": "mop", "x": 260},
        {"id": "chair", "x": 560},
        {"id": "mop", "x": 780},
    ],
    "npcs": [
        {"id": "laundry_lady", "name": "Attendant", "character": "laundry_lady", "x": 120,
         "y": LANE_MIN + 2, "dialogue": "laundry_lady_line", "if_not_flag": "chapter_1_done"},
    ],
    "doors": [
        {"id": "to_yard", "to": "rustpile_yard", "spawn": "from_hideout", "x": 16,
         "y": LANE_MAX - 16, "label": "Leave", "auto": True, "w": 22, "h": 46},
        {"id": "laundry_counter_door", "shop": "laundry_counter", "x": 160, "y": LANE_MIN - 2,
         "label": "Front Counter"},
    ],
    "spawns": [
        {"id": "start", "x": 70, "y": 58},
    ],
    "encounters": [
        {"id": "hideout_guards", "x": 340, "width": 70},
        {"id": "hideout_elites", "x": 640, "width": 80},
        {"id": "boss_starch", "x": 880, "width": 70},
    ],
    "lane_min": 38.0,
    "lane_max": 76.0,
    # Interior, and the only bright area in the game. Cold overhead fluorescent, evenly
    # spaced, no shadows worth the name. A laundromat that is always immaculate should
    # feel over-lit rather than atmospheric.
    "lighting": lighting(
        (0.70, 0.72, 0.78),
        # Weak lights on an already-bright ambient. At full strength they simply added to
        # it and the floor went to white, which is not "over-lit", it is missing.
        [light(x, 30.0, (0.80, 0.90, 1.0), 0.30, 2.0, "wide") for x in range(120, W5, 200)]
        + [light(160, 24.0, (1.0, 0.9, 0.7), 0.30, 1.1, "tight")],
    ),
}
build("starch_laundromat", W5, hideout)

# ===========================================================================
# AREA 6 - METRO PLATFORM : chapter two opens, second dojo, the locker
# ===========================================================================
W6 = 1300
metro = {
    "parallax": [
        # 1:1, not 2x. At 2x a single tunnel mouth fills the whole screen.
        {"texture": _tex_path("metro_wall"), "y": -170.0, "scroll": 0.55, "repeat": 8,
         "scale": 1.0, "z": -90},
    ],
    "ground": [
        fill((0.08, 0.09, 0.12), -400.0, 620, -40, W6 + 40, z=-95),
        fill((0.20, 0.21, 0.25), SIDEWALK_TOP - 16.0, 460, -40, W6 + 40),
        ground("metal", ROAD_TOP, 3, -40, W6 + 40, z=-24),
        ground("curb", CURB_TOP, 1, -40, W6 + 40, z=-23),
        ground("tile_floor", SIDEWALK_TOP - 16.0, SIDEWALK_ROWS + 1, -40, W6 + 40, z=-22),
    ],
    "scenery": [
        scenery(PROP + "metro_sign", 90, ROAD_TOP - 26, z=-28, flicker=0.08, flicker_speed=3.1),
        scenery(PROP + "sign", 560, ROAD_TOP - 44, z=-28),
        # Bex's dojo. The door into it was a bare stretch of platform wall with an
        # invisible trigger in it -- the only shop in the game with no shopfront.
        building("shop_dojo", 630, 212, z=-30),
        scenery(PROP + "ac_unit", 820, ROAD_TOP - 24, z=-28),
        scenery(PROP + "sign", 1104, ROAD_TOP - 44, z=-28),
        scenery(PROP + "metro_sign", 1220, ROAD_TOP - 26, z=-28, flicker=0.08, flicker_speed=3.1),
    ],
    "props": [
        prop("turnstile", 130, LANE_MIN - 4, solid=True),
        prop("turnstile", 170, LANE_MIN - 4, solid=True),
        prop("ticket_machine", 230, LANE_MIN - 5, solid=True, searchable=True,
             dialogue="metro_poster", prompt="Read notice"),
        prop("bench", 400, LANE_MIN - 2),
        prop("locker", 440, LANE_MIN - 4, solid=True),
        prop("locker", 470, LANE_MIN - 4, solid=True, searchable=True,
             dialogue="locker_found", prompt="Open locker 12"),
        prop("locker", 500, LANE_MIN - 4, solid=True),
        prop("trashcan", 540, breakable=True, hp=10, money=16, contains="platform_coffee"),
        prop("planter", 640, LANE_MAX - 4),
        prop("bench", 760, LANE_MIN - 2),
        prop("trashcan", 880, breakable=True, hp=10, money=13),
        prop("crate", 960, breakable=True, hp=8, contains="weapon:pipe"),
        prop("planter", 1040, LANE_MAX - 4),
        prop("bench", 1150, LANE_MIN - 2),
        prop("trashcan", 1240, breakable=True, hp=10, money=20, contains="lost_sandwich"),
    ],
    "weapons": [
        {"id": "mop", "x": 700},
        {"id": "pipe", "x": 1100},
    ],
    "npcs": [
        {"id": "bex", "name": "Bex", "character": "bex", "x": 660, "y": LANE_MIN + 2,
         "conditional": [{"dialogue": "bex_shop", "if_flag": "met_bex"}],
         "dialogue": "bex_intro"},
        {"id": "train_guard", "name": "Guard", "character": "train_guard", "x": 200,
         "y": LANE_MIN + 5, "dialogue": "train_guard_line"},
    ],
    "doors": [
        {"id": "to_market", "to": "lantern_market", "spawn": "from_metro", "x": 16,
         "y": LANE_MAX - 16, "label": "Lantern Market", "auto": True, "w": 22, "h": 46},
        {"id": "to_bellwater", "to": "bellwater_block", "spawn": "from_metro", "x": W6 - 24,
         "y": LANE_MAX - 16, "label": "Bellwater Block", "auto": True, "w": 22, "h": 46},
        {"id": "to_office", "to": "line_office", "spawn": "from_metro", "x": 1120,
         "y": LANE_MIN - 2, "label": "Line Office", "required_flag": "bellwater_cleared",
         "locked": "LINE OFFICE. The handle turns; the door does not.", "w": 24, "h": 40},
        {"id": "bex_dojo_door", "shop": "bex_dojo", "x": 690, "y": LANE_MIN - 2,
         "label": "Metro Line School", "required_flag": "met_bex",
         "locked": "Bex has not invited you in yet."},
    ],
    "spawns": [
        {"id": "start", "x": 80, "y": 58},
        {"id": "from_market", "x": 90, "y": 58},
        {"id": "from_bellwater", "x": W6 - 70, "y": 58},
        {"id": "from_office", "x": 1110, "y": 60},
    ],
    "encounters": [
        {"id": "metro_platform_1", "x": 380, "width": 70},
        {"id": "metro_platform_2", "x": 1000, "width": 80},
    ],
    "on_enter": [
        {"dialogue": "metro_arrival", "if_not_flag": "seen_metro"},
    ],
    "lane_min": 38.0,
    "lane_max": 76.0,
    # Underground: no sky, so every photon here comes from a fitting somebody installed.
    # The ambient is cool and low, and the platform lights are warm, which is what makes
    # the pools read as pools rather than as brighter floor.
    "lighting": lighting(
        (0.34, 0.37, 0.52),
        [light(x, 30.0, (1.0, 0.84, 0.56), 1.35, 2.3) for x in range(90, W6, 210)]
        + [
            # Tunnel mouths at either end, cold and dim, so the exits read as depth.
            light(-10, -30.0, (0.45, 0.62, 0.95), 0.9, 2.6, "wide"),
            light(W6 + 10, -30.0, (0.45, 0.62, 0.95), 0.9, 2.6, "wide"),
            # The ticket machine and the sign throw a little of their own colour.
            light(236, 22.0, (0.5, 0.95, 0.9), 0.55, 0.9, "tight"),
            light(1226, 8.0, (0.45, 0.7, 1.0), 0.6, 1.0, "tight"),
            # Bex's doorway, so the dojo reads as somewhere you can go in.
            light(700, 26.0, (1.0, 0.72, 0.42), 0.8, 1.3, "tight"),
        ],
    ),
}
build("metro_platform", W6, metro)

# ===========================================================================
# AREA 7 - ROOFTOP ROUTE : the way over Bellwater, ambush, no shops
# ===========================================================================
W7 = 1200
rooftop = {
    "parallax": [
        sky("rooftop_sky", -430.0, 0.02, 4, 2.2, z=-95),
        sky("skyline_far", -150.0, 0.2, 4, 1.0, [0.58, 0.58, 0.8], z=-90),
        sky("skyline_near", -104.0, 0.42, 4, 1.0, [0.74, 0.72, 0.9], z=-85),
    ],
    "ground": [
        fill((0.38, 0.37, 0.40), SIDEWALK_TOP - 10.0, 460, -40, W7 + 40),
        ground("metal", ROAD_TOP, 3, -40, W7 + 40, z=-24),
        ground("curb", CURB_TOP, 1, -40, W7 + 40, z=-23),
        ground("concrete", SIDEWALK_TOP - 10.0, SIDEWALK_ROWS + 1, -40, W7 + 40, z=-22),
    ],
    "scenery": [
        # A roof has no building behind it, so everything stands on the parapet line.
        scenery(PROP + "aerial", 120, ROAD_TOP - 40, z=-28, sway=1, sway_speed=2.1),
        scenery(PROP + "satellite_dish", 300, ROAD_TOP - 26, z=-28),
        scenery(PROP + "laundry_line", 430, ROAD_TOP - 26, z=-28, sway=2, sway_speed=0.8),
        scenery(PROP + "aerial", 620, ROAD_TOP - 40, z=-28, sway=1, sway_speed=2.1),
        scenery(PROP + "ac_unit", 780, ROAD_TOP - 24, z=-28),
        scenery(PROP + "laundry_line", 900, ROAD_TOP - 26, z=-28, sway=2, sway_speed=0.8),
        scenery(PROP + "satellite_dish", 1080, ROAD_TOP - 26, z=-28),
        scenery(PROP + "aerial", 1160, ROAD_TOP - 40, z=-28, sway=1, sway_speed=2.1),
    ],
    "props": [
        prop("roof_vent", 160, LANE_MIN - 4, solid=True),
        prop("crate", 250, breakable=True, hp=8, money=15),
        prop("pallet", 330, LANE_MIN - 2),
        prop("roof_vent", 420, LANE_MIN - 4, solid=True),
        prop("barrel", 500, breakable=True, hp=12, contains="platform_coffee"),
        prop("tire", 580, LANE_MAX - 4),
        prop("crate", 700, breakable=True, hp=8, contains="weapon:plank"),
        prop("roof_vent", 800, LANE_MIN - 4, solid=True),
        prop("bin_bags", 880),
        prop("barrel", 980, breakable=True, hp=12, money=26),
        prop("crate", 1090, breakable=True, hp=8, contains="lost_sandwich"),
    ],
    "weapons": [
        {"id": "plank", "x": 380},
        {"id": "brick", "x": 860},
    ],
    "npcs": [
        {"id": "roof_kid", "name": "Kid", "character": "roof_kid", "x": 200,
         "y": LANE_MIN + 6,
         "conditional": [{"dialogue": "roof_kid_done", "if_quest": ["q_roof", "ready"]}],
         "dialogue": "roof_kid_intro", "wander": True},
    ],
    "doors": [
        {"id": "to_alley", "to": "grease_alley", "spawn": "from_roof", "x": 16,
         "y": LANE_MAX - 16, "label": "Down to Grease Alley", "auto": True, "w": 22, "h": 46},
        {"id": "to_bellwater", "to": "bellwater_block", "spawn": "from_roof", "x": W7 - 24,
         "y": LANE_MAX - 16, "label": "Down to Bellwater", "auto": True, "w": 22, "h": 46},
    ],
    "spawns": [
        {"id": "start", "x": 80, "y": 58},
        {"id": "from_alley", "x": 90, "y": 58},
        {"id": "from_bellwater", "x": W7 - 70, "y": 58},
    ],
    "encounters": [
        {"id": "rooftop_ambush", "x": 640, "width": 80},
    ],
    "lane_min": 36.0,
    "lane_max": 74.0,
    "ambient": ambient(drift=litter(count=10, speed=22.0)),
    # Night, above the streetlights. Almost all of the light here is the city glowing up
    # from below, so the ambient is cold and the only warm points are an aerial's warning
    # lamp and the spill from the stairwell.
    "lighting": lighting(
        (0.30, 0.34, 0.50),
        [
            light(120, -30.0, (1.0, 0.35, 0.35), 0.9, 1.0, "tight"),   # aerial warning light
            # Stairwells at both ends, which are the only real light sources up here.
            light(30, 44.0, (1.0, 0.78, 0.46), 1.5, 1.8, "tight"),
            light(W7 - 30, 44.0, (1.0, 0.78, 0.46), 1.5, 1.8, "tight"),
            # Skylights and lit vents give the middle of the roof a rhythm. Without them
            # the floor is one flat expanse and the whole area reads as tinted, not lit.
            light(230, 42.0, (0.75, 0.86, 1.0), 1.0, 1.6, "tight"),
            light(430, 40.0, (0.75, 0.86, 1.0), 1.1, 1.7, "tight"),
            light(640, 44.0, (0.95, 0.82, 0.55), 0.9, 1.5, "tight"),
            light(800, 38.0, (0.9, 0.8, 0.6), 0.9, 1.5, "tight"),
            light(1000, 42.0, (0.75, 0.86, 1.0), 1.0, 1.6, "tight"),
            light(1160, -34.0, (1.0, 0.35, 0.35), 0.9, 1.0, "tight"),  # the far aerial
        ],
    ),
}
build("rooftop_route", W7, rooftop)

# ===========================================================================
# AREA 8 - BELLWATER BLOCK : forty flats, one shop, a wall full of Commuters
# ===========================================================================
W8 = 1500
bellwater = {
    "parallax": [
        sky("sky_day", -430.0, 0.02, 4, 2.2, [0.82, 0.82, 0.94], z=-95),
        sky("skyline_far", -120.0, 0.25, 4, 1.0, [0.6, 0.6, 0.8], z=-90),
        sky("skyline_near", -86.0, 0.5, 4, 1.0, [0.76, 0.76, 0.9], z=-85),
    ],
    "ground": street_ground(W8),
    "scenery": (
        [
            building("apartment_b", 30, 276, z=-30),
            building("apartment_a", 170, 256, z=-30),
            building("apartment_c", 300, 236, z=-30, flip=True),
            building("shop_corner", 440, 196, z=-30),
            building("apartment_b", 600, 276, z=-30),
            building("apartment_a", 740, 256, z=-30, flip=True),
            building("apartment_c", 880, 236, z=-30),
            building("apartment_b", 1010, 276, z=-30, flip=True),
            building("warehouse", 1150, 150, z=-30),
            building("apartment_a", 1360, 256, z=-30),
            scenery(PROP + "awning_green", 444, DECO_BASE - 66, z=-28, sway=1, sway_speed=1.1),
            scenery(PROP + "graffiti_b", 700, DECO_BASE - 62, z=-27),
            scenery(PROP + "laundry_line", 250, DECO_BASE - 120, z=-28, sway=2, sway_speed=0.8),
            scenery(PROP + "laundry_line", 950, DECO_BASE - 126, z=-28, sway=2, sway_speed=0.8),
            scenery(PROP + "satellite_dish", 1058, DECO_BASE - 134, z=-28),
            scenery(PROP + "car_blue", 620, CURB_TOP - 38, z=-21),
            scenery(PROP + "fence", 1440, CURB_TOP - 38, z=-21),
        scenery(PROP + "fire_escape", W8 - 46, DECO_BASE - 140, z=-20),
        ]
        + lamp_row(W8, 200, 110)
    ),
    "props": [
        prop("planter", 120, LANE_MAX - 4),
        prop("bench", 220, LANE_MIN - 2),
        prop("trashcan", 320, breakable=True, hp=10, money=14, contains="bellwater_stew"),
        prop("planter", 400, LANE_MAX - 4),
        prop("bin_bags", 520),
        prop("crate", 600, breakable=True, hp=8, money=18),
        prop("hydrant", 680),
        prop("bench", 780, LANE_MIN - 2),
        prop("trashcan", 860, breakable=True, hp=10, contains="platform_coffee"),
        prop("puddle", 940, LANE_MAX - 2),
        prop("planter", 1030, LANE_MAX - 4),
        prop("crate", 1120, breakable=True, hp=8, contains="weapon:chair"),
        prop("cone", 1220),
        prop("trashcan", 1300, breakable=True, hp=10, money=28),
        prop("bin_bags", 1400),
    ],
    "weapons": [
        {"id": "bat", "x": 560},
        {"id": "bottle", "x": 900},
        {"id": "pipe", "x": 1260},
    ],
    "npcs": [
        {"id": "nadia", "name": "Nadia", "character": "nadia", "x": 470, "y": LANE_MIN + 2,
         "conditional": [
             {"dialogue": "nadia_closing", "if_flag": "took_the_form", "if_not_flag": "chapter_3_done"},
             {"dialogue": "nadia_done", "if_quest": ["q_commuters", "ready"]},
             {"dialogue": "nadia_shop", "if_flag": "met_nadia"},
         ], "dialogue": "nadia_intro"},
        {"id": "bellwater_local", "name": "Local", "character": "worker", "x": 1080,
         "y": LANE_MIN + 6, "dialogue": "bellwater_local", "wander": True},
    ],
    "doors": [
        {"id": "to_metro", "to": "metro_platform", "spawn": "from_bellwater", "x": 16,
         "y": LANE_MAX - 16, "label": "Metro Platform", "auto": True, "w": 22, "h": 46},
        {"id": "to_roof", "to": "rooftop_route", "spawn": "from_bellwater", "x": W8 - 24,
         "y": LANE_MAX - 16, "label": "Fire Escape", "auto": True, "w": 22, "h": 46},
        {"id": "nadia_store_door", "shop": "nadia_store", "x": 500, "y": LANE_MIN - 2,
         "label": "Nadia's Corner", "required_flag": "met_nadia",
         "locked": "The shutter is half down. Talk to her first."},
    ],
    "spawns": [
        {"id": "start", "x": 80, "y": 58},
        {"id": "from_metro", "x": 90, "y": 58},
        {"id": "from_roof", "x": W8 - 70, "y": 58},
    ],
    "encounters": [
        {"id": "bellwater_wall", "x": 700, "width": 70},
        {"id": "bellwater_conductor", "x": 1220, "width": 80},
    ],
    "ambient": ambient(drift=litter(count=7, speed=-13.0)),
    # Night on a residential block. Cool and quiet, with the only real warmth coming from
    # Nadia's, which is the point of the place: forty flats and one shop that is open.
    "lighting": lighting(
        (0.44, 0.46, 0.62),
        lamp_lights(W8, 200, 110, (1.0, 0.84, 0.56), 1.2, 2.1)
        + [
            light(500, 24.0, (1.0, 0.78, 0.46), 1.2, 1.9, "tight"),   # Nadia's Corner
            light(250, -60.0, (1.0, 0.88, 0.62), 0.4, 1.2, "tight"),  # a lit window
            light(950, -66.0, (1.0, 0.88, 0.62), 0.4, 1.2, "tight"),
        ],
    ),
}
build("bellwater_block", W8, bellwater)

# ===========================================================================
# AREA 9 - LINE OFFICE : chapter two's answer. No enemies, no shop, one desk.
# ===========================================================================
W9 = 700
office = {
    "parallax": [
        {"texture": _tex_path("interior_wall"), "y": -370.0, "scroll": 0.8, "repeat": 4,
         "scale": 2.0, "z": -90},
    ],
    "ground": [
        fill((0.30, 0.28, 0.26), SIDEWALK_TOP - 16.0, 460, -40, W9 + 40),
        ground("wood_floor", SIDEWALK_TOP - 16.0, SIDEWALK_ROWS + 1, -40, W9 + 40, z=-22),
    ],
    "scenery": [
        scenery(PROP + "filing_cabinet", 90, ROAD_TOP - 44, z=-28),
        scenery(PROP + "filing_cabinet", 118, ROAD_TOP - 44, z=-28),
        scenery(PROP + "filing_cabinet", 146, ROAD_TOP - 44, z=-28),
        scenery(PROP + "filing_cabinet", 174, ROAD_TOP - 44, z=-28),
        scenery(PROP + "sign", 300, ROAD_TOP - 44, z=-28),
        scenery(PROP + "ac_unit", 470, ROAD_TOP - 24, z=-28),
        scenery(PROP + "flyer", 560, ROAD_TOP - 20, z=-27),
        scenery(PROP + "doorway", 626, DECO_BASE - 52, z=-20),
    ],
    "props": [
        prop("desk", 430, LANE_MIN - 6, solid=True, searchable=True,
             dialogue="metro_poster", prompt="Read the notice"),
        prop("bench", 210, LANE_MIN - 2),
        prop("trashcan", 620, breakable=True, hp=10, money=18),
        prop("crate", 120, LANE_MAX - 6, breakable=True, hp=8, contains="lost_sandwich"),
    ],
    "weapons": [],
    "npcs": [
        {"id": "line_manager", "name": "Line Manager", "character": "line_manager",
         "x": 470, "y": LANE_MIN + 2,
         "conditional": [
             {"dialogue": "manager_form", "if_flag": "chapter_2_done", "if_not_flag": "took_the_form"},
             {"dialogue": "manager_after", "if_flag": "took_the_form"},
         ],
         "dialogue": "manager_reveal"},
    ],
    "doors": [
        {"id": "to_metro", "to": "metro_platform", "spawn": "from_office", "x": 16,
         "y": LANE_MAX - 16, "label": "Back to the platform", "auto": True, "w": 22, "h": 46},
        {"id": "to_stair", "to": "service_stair", "spawn": "from_office", "x": 640,
         "y": LANE_MIN - 2, "label": "Service stair", "required_flag": "took_the_form",
         "locked": "A door onto the line itself. No reason to go down there.",
         "w": 30, "h": 46},
    ],
    "spawns": [
        {"id": "start", "x": 80, "y": 58},
        {"id": "from_metro", "x": 80, "y": 58},
        {"id": "from_stair", "x": 600, "y": 58},
    ],
    "encounters": [],
    "on_enter": [
        {"cutscene": "line_office_arrival", "if_not_flag": "seen_line_office"},
    ],
    "lane_min": 38.0,
    "lane_max": 76.0,
    # Strip lighting and a desk lamp. Warmer and smaller than the platform outside, which
    # is the point: this is the one room on the line where somebody actually works.
    "lighting": lighting(
        (0.60, 0.58, 0.62),
        [light(x, 34.0, (1.0, 0.92, 0.74), 0.55, 2.0, "wide") for x in range(120, W9, 220)]
        + [light(455, 26.0, (1.0, 0.84, 0.5), 0.8, 1.3, "tight")],
    ),
}
build("line_office", W9, office)

# ===========================================================================
# AREA 10 - SERVICE STAIR : the way down. Short, tight, first sight of the crew.
# ===========================================================================
W10 = 760
stair = {
    "parallax": [
        {"texture": _tex_path("tunnel_wall"), "y": -390.0, "scroll": 0.85, "repeat": 4,
         "scale": 2.0, "z": -90},
    ],
    "ground": [
        fill((0.17, 0.17, 0.20), SIDEWALK_TOP - 16.0, 460, -40, W10 + 40),
        ground("concrete", SIDEWALK_TOP - 16.0, SIDEWALK_ROWS + 1, -40, W10 + 40, z=-22),
    ],
    "scenery": [
        scenery(PROP + "sign", 120, ROAD_TOP - 44, z=-28),
        scenery(PROP + "barrier", 300, DECO_BASE - 26, z=-20),
        scenery(PROP + "barrier", 348, DECO_BASE - 26, z=-20),
        scenery(PROP + "work_lamp", 210, DECO_BASE - 46, z=-20),
        scenery(PROP + "work_lamp", 600, DECO_BASE - 46, z=-20),
        scenery(PROP + "cable_spool", 470, DECO_BASE - 30, z=-20),
        scenery(PROP + "pipe_stack", 690, ROAD_TOP - 30, z=-28),
    ],
    "props": [
        prop("crate", 250, LANE_MAX - 6, breakable=True, hp=8, money=14),
        prop("barrel", 540, LANE_MIN - 4, breakable=True, hp=10, contains="platform_coffee"),
        prop("trashcan", 700, breakable=True, hp=10, money=16),
    ],
    "weapons": [
        {"id": "pipe", "x": 400, "y": LANE_MAX - 8},
    ],
    "npcs": [],
    "doors": [
        {"id": "to_office", "to": "line_office", "spawn": "from_stair", "x": 16,
         "y": LANE_MAX - 16, "label": "Back up to the office", "auto": True, "w": 22, "h": 46},
        {"id": "to_line", "to": "line_four", "spawn": "from_stair", "x": W10 - 24,
         "y": LANE_MAX - 16, "label": "Down to the platform", "auto": True, "w": 22, "h": 46},
    ],
    "spawns": [
        {"id": "start", "x": 80, "y": 58},
        {"id": "from_office", "x": 80, "y": 58},
        {"id": "from_line", "x": W10 - 80, "y": 58},
    ],
    "encounters": [
        {"id": "stair_crew", "x": 330, "width": 60},
    ],
    "lane_min": 40.0,
    "lane_max": 78.0,
    # Almost no ambient: this is underground and the building lights are off. What you can
    # see, you can see because the crew plugged something in.
    "lighting": lighting(
        (0.30, 0.30, 0.36),
        [light(210, 40.0, (1.0, 0.96, 0.86), 1.5, 1.7, "wide"),
         light(600, 40.0, (1.0, 0.96, 0.86), 1.5, 1.7, "wide"),
         light(400, 34.0, (0.72, 0.80, 1.0), 0.4, 2.4, "wide")],
    ),
    "ambient": ambient(),
}
build("service_stair", W10, stair)

# ===========================================================================
# AREA 11 - LINE 4 : the platform itself, being taken apart. The long fight.
# ===========================================================================
W11 = 1560
line_four = {
    "parallax": [
        {"texture": _tex_path("tunnel_wall"), "y": -390.0, "scroll": 0.85, "repeat": 7,
         "scale": 2.0, "z": -90},
    ],
    "ground": [
        fill((0.15, 0.15, 0.19), SIDEWALK_TOP - 16.0, 460, -40, W11 + 40),
        ground("tile_floor", SIDEWALK_TOP - 16.0, SIDEWALK_ROWS + 1, -40, W11 + 40, z=-22),
        ground("metal", ROAD_TOP - 4.0, 1, -40, W11 + 40, z=-23),
    ],
    "scenery": [
        scenery(PROP + "work_lamp", 180, DECO_BASE - 46, z=-20),
        scenery(PROP + "work_lamp", 620, DECO_BASE - 46, z=-20),
        scenery(PROP + "work_lamp", 1080, DECO_BASE - 46, z=-20),
        scenery(PROP + "work_lamp", 1440, DECO_BASE - 46, z=-20),
        scenery(PROP + "barrier", 360, DECO_BASE - 26, z=-20),
        scenery(PROP + "barrier", 404, DECO_BASE - 26, z=-20),
        scenery(PROP + "barrier", 900, DECO_BASE - 26, z=-20),
        scenery(PROP + "cable_spool", 760, DECO_BASE - 30, z=-20),
        scenery(PROP + "cable_spool", 1240, DECO_BASE - 30, z=-20),
        scenery(PROP + "pipe_stack", 240, ROAD_TOP - 30, z=-28),
        scenery(PROP + "pipe_stack", 1320, ROAD_TOP - 30, z=-28),
        scenery(PROP + "metro_sign", 520, ROAD_TOP - 72, z=-28),
        scenery(PROP + "bench", 980, ROAD_TOP - 20, z=-28),
        scenery(PROP + "graffiti_c", 1150, ROAD_TOP - 40, z=-27),
        scenery(PROP + "steel_door", 1520, DECO_BASE - 52, z=-20),
    ],
    "props": [
        prop("crate", 300, LANE_MAX - 6, breakable=True, hp=8, money=16),
        prop("crate", 330, LANE_MAX - 2, breakable=True, hp=8, contains="rice_ball"),
        prop("barrel", 700, LANE_MIN - 4, breakable=True, hp=10, money=22),
        prop("barrel", 1180, LANE_MAX - 8, breakable=True, hp=10, contains="bellwater_stew"),
        prop("trashcan", 1400, breakable=True, hp=10, money=20),
        prop("bench", 860, LANE_MIN - 2),
    ],
    "weapons": [
        {"id": "pipe", "x": 640, "y": LANE_MAX - 8},
        {"id": "plank", "x": 1120, "y": LANE_MIN - 6},
    ],
    "npcs": [],
    "doors": [
        {"id": "to_stair", "to": "service_stair", "spawn": "from_line", "x": 16,
         "y": LANE_MAX - 16, "label": "Back up the stair", "auto": True, "w": 22, "h": 46},
        {"id": "to_substation", "to": "substation", "spawn": "from_line", "x": W11 - 26,
         "y": LANE_MIN - 2, "label": "Substation", "required_flag": "line_four_cleared",
         "locked": "Steel door. Somebody is working on the other side of it.",
         "w": 30, "h": 46},
    ],
    "spawns": [
        {"id": "start", "x": 80, "y": 58},
        {"id": "from_stair", "x": 80, "y": 58},
        {"id": "from_substation", "x": W11 - 90, "y": 58},
    ],
    "encounters": [
        {"id": "line_four_1", "x": 430, "width": 80},
        {"id": "line_four_2", "x": 1040, "width": 90},
    ],
    "lane_min": 40.0,
    "lane_max": 80.0,
    "lighting": lighting(
        (0.26, 0.27, 0.34),
        [light(x, 40.0, (1.0, 0.96, 0.86), 1.5, 1.8, "wide")
         for x in (180, 620, 1080, 1440)]
        # The two strip lights still alive on the whole platform, cold and nearly useless.
        + [light(x, 30.0, (0.70, 0.80, 1.0), 0.38, 2.6, "wide") for x in (400, 900, 1300)],
    ),
    "ambient": ambient(litter(5, 9.0, [[0.62, 0.60, 0.55], [0.50, 0.48, 0.44]])),
}
build("line_four", W11, line_four)

# ===========================================================================
# AREA 12 - SUBSTATION : where the line gets switched off. The Foreman.
# ===========================================================================
W12 = 820
substation = {
    "parallax": [
        {"texture": _tex_path("substation_wall"), "y": -370.0, "scroll": 0.9, "repeat": 4,
         "scale": 2.0, "z": -90},
    ],
    "ground": [
        fill((0.19, 0.18, 0.20), SIDEWALK_TOP - 16.0, 460, -40, W12 + 40),
        # Concrete, not metal. The metal tile is vertically grooved and reads as corrugated
        # siding: laid across the floor it looked like a wall the player was standing on.
        ground("concrete", SIDEWALK_TOP - 16.0, SIDEWALK_ROWS + 1, -40, W12 + 40, z=-22),
        ground("metal", ROAD_TOP - 4.0, 1, -40, W12 + 40, z=-23),
    ],
    "scenery": [
        scenery(PROP + "switchgear", 120, ROAD_TOP - 62, z=-28),
        scenery(PROP + "switchgear", 168, ROAD_TOP - 62, z=-28),
        scenery(PROP + "switchgear", 216, ROAD_TOP - 62, z=-28),
        scenery(PROP + "switchgear", 640, ROAD_TOP - 62, z=-28),
        scenery(PROP + "switchgear", 688, ROAD_TOP - 62, z=-28),
        scenery(PROP + "work_lamp", 400, DECO_BASE - 46, z=-20),
        scenery(PROP + "cable_spool", 560, DECO_BASE - 30, z=-20),
        scenery(PROP + "ac_unit", 340, ROAD_TOP - 30, z=-28),
    ],
    "props": [
        prop("crate", 260, LANE_MAX - 6, breakable=True, hp=8, contains="hot_soup"),
        prop("barrel", 760, LANE_MIN - 4, breakable=True, hp=10, money=30),
    ],
    "weapons": [
        {"id": "pipe", "x": 300, "y": LANE_MAX - 8},
    ],
    "npcs": [],
    "doors": [
        {"id": "to_line", "to": "line_four", "spawn": "from_substation", "x": 16,
         "y": LANE_MAX - 16, "label": "Back to the platform", "auto": True, "w": 22, "h": 46},
    ],
    "spawns": [
        {"id": "start", "x": 90, "y": 58},
        {"id": "from_line", "x": 90, "y": 58},
    ],
    "encounters": [
        {"id": "boss_foreman", "x": 430, "width": 70},
    ],
    # On clear, not on enter: you are already in the substation when you beat him, so an
    # on_enter ending can only play if you leave and walk back in.
    "on_clear": [
        {"encounter": "boss_foreman", "cutscene": "chapter_three_end",
         "if_not_flag": "seen_ch3_end"},
    ],
    "lane_min": 40.0,
    "lane_max": 78.0,
    # One work lamp and the indicator glow off the switchgear. A boss room lit by a man
    # who brought exactly enough light to read by.
    "lighting": lighting(
        (0.32, 0.30, 0.34),
        [light(400, 40.0, (1.0, 0.96, 0.86), 1.7, 2.0, "wide"),
         light(170, 30.0, (0.5, 1.0, 0.7), 0.42, 1.2, "tight"),
         light(664, 30.0, (0.5, 1.0, 0.7), 0.42, 1.2, "tight")],
    ),
    "ambient": ambient(),
}
build("substation", W12, substation)


print("12 area layouts written to data/areas/")

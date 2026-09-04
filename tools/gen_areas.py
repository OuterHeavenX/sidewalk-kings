#!/usr/bin/env python3
"""
Sidewalk Kings - area layout generator.

Each playable area is a JSON layout in res://data/areas/. Area.gd reads it and builds the
street at runtime: parallax, ground tiles, buildings, props, weapons, NPCs, doors, spawns
and encounter triggers. Adding a neighbourhood means adding a layout here.

Run from the project root:  python tools/gen_areas.py
"""
import os, json, random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "areas")
os.makedirs(OUT, exist_ok=True)

BG = "res://assets/art/backgrounds/"
PROP = "res://assets/art/props/"

# Vertical layout, in world pixels. y grows downward and doubles as lane depth:
# a smaller y is further into the screen, which is what drives Y-sorting.
#
#   ROAD_TOP  -46 ┬ road (parked cars, back edge of the scene)
#   BUILD_BASE  2 ┼ buildings stand on this line
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
BUILD_BASE = 2.0      # buildings rest here, behind the road
CAMERA_Y = -12.0      # camera centre; shows roughly y -147..123 at 480x270
GROUND_Y = BUILD_BASE


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


def scenery(tex, x, y, z=-10, scale=1.0, front=False, flip=False, modulate=None):
    d = {"texture": _tex_path(tex), "x": x, "y": y, "z": z, "scale": scale}
    if front:
        d["front"] = True
    if flip:
        d["flip"] = True
    if modulate:
        d["modulate"] = modulate
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


def building(tex, x, height, z=-30, **kw):
    """Place a building so its base sits on the road's far edge."""
    return scenery(tex, x, BUILD_BASE - height, z=z, **kw)


def lamp_row(width, spacing=170, start=60):
    """Street lights stand on the back edge of the sidewalk."""
    out = []
    x = start
    while x < width - 40:
        out.append(scenery(PROP + "streetlight", x, SIDEWALK_TOP - 96.0, z=-8))
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
            scenery(PROP + "awning_blue", 214, BUILD_BASE - 62, z=-28),
            scenery(PROP + "awning_red", 646, BUILD_BASE - 70, z=-28),
            scenery(PROP + "graffiti_a", 420, BUILD_BASE - 60, z=-27),
            scenery(PROP + "graffiti_c", 1130, BUILD_BASE - 56, z=-27),
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
         "conditional": [
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
    "on_enter": [
        {"dialogue": "intro_ferry", "if_not_flag": "seen_intro"},
    ],
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
            scenery(PROP + "awning_red", 194, BUILD_BASE - 70, z=-28),
            scenery(PROP + "awning_green", 354, BUILD_BASE - 66, z=-28),
            scenery(PROP + "awning_blue", 624, BUILD_BASE - 66, z=-28),
            scenery(PROP + "awning_green", 1224, BUILD_BASE - 62, z=-28),
            scenery(PROP + "graffiti_b", 830, BUILD_BASE - 58, z=-27),
            scenery(PROP + "car_yellow", 540, CURB_TOP - 38, z=-21),
            scenery(PROP + "car_red", 1140, CURB_TOP - 38, z=-21),
            scenery("metro_entrance", 1330, BUILD_BASE - 120, z=-29),
            scenery(PROP + "metro_sign", 1368, BUILD_BASE - 142, z=-27),
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
            scenery(PROP + "graffiti_a", 200, BUILD_BASE - 70, z=-27),
            scenery(PROP + "graffiti_b", 520, BUILD_BASE - 76, z=-27),
            scenery(PROP + "graffiti_c", 900, BUILD_BASE - 68, z=-27),
            scenery(PROP + "graffiti_a", 1200, BUILD_BASE - 72, z=-27),
            scenery(PROP + "ac_unit", 340, BUILD_BASE - 130, z=-28),
            scenery(PROP + "ac_unit", 980, BUILD_BASE - 138, z=-28),
            scenery(PROP + "laundry_line", 640, BUILD_BASE - 128, z=-28),
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
        {"id": "to_roof", "to": "rooftop_route", "spawn": "from_alley", "x": 620,
         "y": LANE_MIN - 2, "label": "Fire Escape", "required_flag": "metro_open",
         "locked": "The ladder is folded up out of reach. No reason to want it yet.",
         "w": 24, "h": 40},
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
        scenery(PROP + "locker", 90, BUILD_BASE - 108, z=-28),
        scenery(PROP + "locker", 130, BUILD_BASE - 108, z=-28),
        scenery(PROP + "ac_unit", 400, BUILD_BASE - 150, z=-28),
        scenery(PROP + "sign", 640, BUILD_BASE - 118, z=-28),
        scenery(PROP + "locker", 900, BUILD_BASE - 108, z=-28),
        scenery(PROP + "locker", 940, BUILD_BASE - 108, z=-28),
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
        scenery(PROP + "metro_sign", 90, ROAD_TOP - 26, z=-28),
        scenery(PROP + "sign", 560, ROAD_TOP - 44, z=-28),
        scenery(PROP + "ac_unit", 820, ROAD_TOP - 24, z=-28),
        scenery(PROP + "metro_sign", 1220, ROAD_TOP - 26, z=-28),
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
        {"id": "bex_dojo_door", "shop": "bex_dojo", "x": 690, "y": LANE_MIN - 2,
         "label": "Metro Line School", "required_flag": "met_bex",
         "locked": "Bex has not invited you in yet."},
    ],
    "spawns": [
        {"id": "start", "x": 80, "y": 58},
        {"id": "from_market", "x": 90, "y": 58},
        {"id": "from_bellwater", "x": W6 - 70, "y": 58},
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
        scenery(PROP + "aerial", 120, ROAD_TOP - 40, z=-28),
        scenery(PROP + "satellite_dish", 300, ROAD_TOP - 26, z=-28),
        scenery(PROP + "laundry_line", 430, ROAD_TOP - 26, z=-28),
        scenery(PROP + "aerial", 620, ROAD_TOP - 40, z=-28),
        scenery(PROP + "ac_unit", 780, ROAD_TOP - 24, z=-28),
        scenery(PROP + "laundry_line", 900, ROAD_TOP - 26, z=-28),
        scenery(PROP + "satellite_dish", 1080, ROAD_TOP - 26, z=-28),
        scenery(PROP + "aerial", 1160, ROAD_TOP - 40, z=-28),
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
            scenery(PROP + "awning_green", 444, BUILD_BASE - 66, z=-28),
            scenery(PROP + "graffiti_b", 700, BUILD_BASE - 62, z=-27),
            scenery(PROP + "laundry_line", 250, BUILD_BASE - 120, z=-28),
            scenery(PROP + "laundry_line", 950, BUILD_BASE - 126, z=-28),
            scenery(PROP + "satellite_dish", 1058, BUILD_BASE - 134, z=-28),
            scenery(PROP + "car_blue", 620, CURB_TOP - 38, z=-21),
            scenery(PROP + "fence", 1440, CURB_TOP - 38, z=-21),
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
}
build("bellwater_block", W8, bellwater)

print("8 area layouts written to data/areas/")

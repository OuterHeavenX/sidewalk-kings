#!/usr/bin/env python3
"""
Sidewalk Kings - original pixel-art character generator.

Draws a stylised 16-bit style humanoid rig (~48px tall in a 64x64 frame) for every
character in CHARACTERS, renders each animation frame, packs a sprite sheet PNG and writes
a matching Godot SpriteFrames .tres so the game can use it directly.

Usage:  python tools/gen_characters.py            (from the project root)
Output: assets/art/characters/<id>.png + <id>_frames.tres, assets/art/ui/portraits/<id>.png
"""
import os, math
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_data as D
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_CHARS = os.path.join(ROOT, "assets", "art", "characters")
OUT_PORTRAITS = os.path.join(ROOT, "assets", "art", "ui", "portraits")
FRAME = 64
COLS = 10
OUTLINE = (24, 16, 28, 255)

# ---------------------------------------------------------------------------
# Rig / pose description
# ---------------------------------------------------------------------------
BASE = {
    "hip": (32, 41), "neck": (32, 29), "head": (33, 19),
    "fa": [(35, 30), (37, 36), (38, 42)],   # front arm: shoulder, elbow, hand
    "ba": [(29, 30), (27, 36), (26, 42)],   # back arm
    "fl": [(34, 41), (35, 50), (36, 58)],   # front leg: hip, knee, foot
    "bl": [(30, 41), (29, 50), (28, 58)],   # back leg
    "order": ["ba", "bl", "torso", "fl", "head", "fa"],
    "eyes": "open", "mouth": "flat", "face_dir": 1,
}

def P(**kw):
    """Build a pose from BASE with overrides. dy shifts everything vertically, dx horizontally."""
    pose = {k: (list(v) if isinstance(v, list) else v) for k, v in BASE.items()}
    dy = kw.pop("dy", 0)
    dx = kw.pop("dx", 0)
    for k, v in kw.items():
        pose[k] = v
    if dx or dy:
        for k in ("hip", "neck", "head"):
            pose[k] = (pose[k][0] + dx, pose[k][1] + dy)
        for k in ("fa", "ba", "fl", "bl"):
            pose[k] = [(p[0] + dx, p[1] + dy) for p in pose[k]]
    return pose

def arm(sh, el, hd):
    return [sh, el, hd]

def leg(hp, kn, ft):
    return [hp, kn, ft]

# Walk cycle helper: returns (fl, bl, fa, ba) for phase t in [0,1)
def walk_limbs(t, stride=7, lift=3, arm_swing=5, hip=(32, 41), sh=(32, 30), run=False):
    a = math.sin(t * 2 * math.pi)
    b = math.sin(t * 2 * math.pi + math.pi)
    def L(s, hipx):
        fx = hipx + s * stride
        ky = 50 - (max(0.0, s) * lift if run else max(0.0, s) * lift * 0.6)
        fy = 58 - max(0.0, s) * lift
        kx = hipx + s * stride * 0.5 + (2 if run else 1)
        return [(hipx, hip[1]), (int(round(kx)), int(round(ky))), (int(round(fx)), int(round(fy)))]
    fl = L(a, hip[0] + 2)
    bl = L(b, hip[0] - 2)
    def A(s, shx, front):
        ex = shx + s * arm_swing * 0.6 + (3 if run else 1)
        ey = sh[1] + 6
        hx = shx + s * arm_swing + (5 if run else 1)
        hy = sh[1] + (9 if run else 12) - (2 if run else 0)
        return [(shx, sh[1]), (int(round(ex)), int(round(ey))), (int(round(hx)), int(round(hy)))]
    fa = A(b, sh[0] + 3, True)
    ba = A(a, sh[0] - 3, False)
    return fl, bl, fa, ba

def walk_frame(i, n=6, run=False):
    t = i / n
    fl, bl, fa, ba = walk_limbs(t, stride=9 if run else 6, lift=5 if run else 3, arm_swing=8 if run else 5, run=run)
    bob = -1 if (i % 3 == 1) else 0
    if run:
        return P(fl=fl, bl=bl, fa=fa, ba=ba, dy=bob, neck=(35, 29 + bob), head=(37, 20 + bob), hip=(32, 41 + bob))
    return P(fl=fl, bl=bl, fa=fa, ba=ba, dy=bob)

# ---------------------------------------------------------------------------
# Animation definitions: name -> (frames, fps, loop)
# ---------------------------------------------------------------------------
def build_animations():
    A = {}
    A["idle"] = ([
        P(),
        P(dy=1, fa=arm((35, 31), (37, 37), (38, 42)), ba=arm((29, 31), (27, 37), (26, 42))),
        P(dy=1, fa=arm((35, 31), (37, 37), (38, 43)), ba=arm((29, 31), (27, 37), (26, 43))),
        P(),
    ], 5, True)
    A["walk"] = ([walk_frame(i) for i in range(6)], 10, True)
    A["run"] = ([walk_frame(i, run=True) for i in range(6)], 14, True)
    # Jab: front arm snaps forward
    A["punch1"] = ([
        P(fa=arm((35, 30), (31, 34), (30, 31)), ba=arm((29, 30), (26, 35), (28, 30))),
        P(dx=1, neck=(34, 29), head=(35, 19), fa=arm((36, 30), (44, 30), (52, 30)), ba=arm((29, 30), (26, 35), (28, 31))),
        P(dx=1, neck=(34, 29), head=(35, 19), fa=arm((36, 30), (43, 30), (50, 30)), ba=arm((29, 30), (26, 35), (28, 31))),
        P(fa=arm((35, 30), (39, 33), (40, 31)), ba=arm((29, 30), (26, 35), (28, 31))),
    ], 18, False)
    # Cross: back arm drives forward across the body
    A["punch2"] = ([
        P(fa=arm((35, 30), (40, 33), (41, 30)), ba=arm((29, 30), (24, 33), (24, 30))),
        P(dx=2, neck=(36, 29), head=(37, 19), order=["bl", "fa", "torso", "fl", "head", "ba"],
          fa=arm((36, 31), (40, 35), (41, 32)), ba=arm((31, 30), (42, 29), (54, 29))),
        P(dx=2, neck=(36, 29), head=(37, 19), order=["bl", "fa", "torso", "fl", "head", "ba"],
          fa=arm((36, 31), (40, 35), (41, 32)), ba=arm((31, 30), (41, 29), (52, 29))),
        P(fa=arm((35, 30), (39, 33), (40, 31)), ba=arm((29, 30), (27, 35), (30, 32))),
    ], 18, False)
    # Hook / body blow finisher
    A["punch3"] = ([
        P(dx=-1, fa=arm((34, 30), (28, 36), (26, 40)), ba=arm((29, 30), (25, 35), (27, 31))),
        P(dx=3, dy=1, neck=(36, 30), head=(37, 20), fa=arm((37, 31), (46, 36), (54, 33)), ba=arm((30, 31), (27, 35), (30, 31))),
        P(dx=3, dy=1, neck=(36, 30), head=(37, 20), fa=arm((37, 31), (46, 35), (55, 31)), ba=arm((30, 31), (27, 35), (30, 31))),
        P(dx=1, fa=arm((36, 30), (42, 34), (44, 31)), ba=arm((29, 30), (27, 35), (30, 31))),
    ], 16, False)
    # Front kick
    A["kick"] = ([
        P(fl=leg((34, 41), (38, 46), (34, 51)), fa=arm((35, 30), (31, 34), (30, 30)), ba=arm((29, 30), (25, 34), (26, 29))),
        P(dx=1, fl=leg((35, 40), (44, 40), (54, 39)), bl=leg((30, 41), (29, 50), (28, 58)), neck=(33, 29), head=(33, 19),
          fa=arm((35, 30), (31, 34), (30, 31)), ba=arm((29, 30), (24, 34), (25, 30))),
        P(dx=1, fl=leg((35, 40), (44, 40), (55, 39)), neck=(33, 29), head=(33, 19),
          fa=arm((35, 30), (31, 34), (30, 31)), ba=arm((29, 30), (24, 34), (25, 30))),
        P(fl=leg((34, 41), (39, 47), (38, 55)), fa=arm((35, 30), (33, 35), (34, 32)), ba=arm((29, 30), (26, 35), (27, 32))),
    ], 16, False)
    # Heavy haymaker
    A["heavy"] = ([
        P(dx=-2, neck=(30, 30), head=(30, 20), fa=arm((33, 31), (24, 30), (18, 26)), ba=arm((27, 31), (23, 36), (24, 31))),
        P(dx=-2, neck=(30, 30), head=(30, 20), fa=arm((33, 31), (24, 28), (17, 22)), ba=arm((27, 31), (23, 36), (24, 31))),
        P(dx=4, dy=1, neck=(37, 30), head=(38, 20), fa=arm((38, 31), (48, 30), (58, 29)), ba=arm((31, 31), (28, 36), (30, 32)),
          fl=leg((36, 42), (42, 49), (46, 58)), bl=leg((30, 42), (26, 50), (22, 58))),
        P(dx=4, dy=1, neck=(37, 30), head=(38, 20), fa=arm((38, 31), (48, 31), (58, 31)), ba=arm((31, 31), (28, 36), (30, 32)),
          fl=leg((36, 42), (42, 49), (46, 58)), bl=leg((30, 42), (26, 50), (22, 58))),
        P(dx=2, fa=arm((36, 30), (42, 34), (44, 34)), ba=arm((30, 30), (27, 35), (29, 33))),
    ], 14, False)
    # Uppercut
    A["uppercut"] = ([
        P(dy=4, hip=(32, 45), neck=(31, 34), head=(32, 24), fl=leg((34, 45), (38, 51), (36, 58)), bl=leg((30, 45), (27, 52), (28, 58)),
          fa=arm((34, 35), (33, 42), (36, 47)), ba=arm((28, 35), (25, 41), (27, 45))),
        P(dy=-2, neck=(33, 27), head=(34, 17), fa=arm((36, 28), (41, 22), (40, 12)), ba=arm((29, 28), (26, 34), (28, 30)),
          fl=leg((34, 39), (36, 47), (36, 56)), bl=leg((30, 39), (28, 47), (27, 56))),
        P(dy=-4, neck=(33, 25), head=(34, 15), fa=arm((36, 26), (40, 18), (39, 8)), ba=arm((29, 26), (26, 32), (28, 28)),
          fl=leg((34, 37), (37, 44), (36, 52)), bl=leg((30, 37), (28, 45), (27, 54))),
        P(fa=arm((35, 30), (39, 33), (40, 29)), ba=arm((29, 30), (26, 35), (28, 31))),
    ], 14, False)
    # Spin kick (body turns away then whips leg round)
    A["spin_kick"] = ([
        P(dx=-1, fl=leg((34, 41), (36, 48), (33, 56)), fa=arm((35, 30), (31, 34), (30, 30)), ba=arm((29, 30), (25, 34), (26, 30))),
        P(face_dir=-1, eyes="none", order=["fa", "fl", "torso", "bl", "head", "ba"], fa=arm((29, 30), (25, 35), (24, 31)), ba=arm((35, 30), (38, 35), (39, 31)),
          fl=leg((30, 41), (26, 47), (20, 50)), bl=leg((34, 41), (35, 50), (36, 58))),
        P(dx=2, dy=-2, neck=(33, 27), head=(33, 17), fl=leg((35, 39), (46, 36), (57, 32)), bl=leg((30, 39), (29, 48), (28, 56)),
          fa=arm((36, 28), (31, 32), (30, 28)), ba=arm((29, 28), (24, 32), (24, 27))),
        P(dx=2, dy=-1, neck=(33, 28), head=(33, 18), fl=leg((35, 40), (46, 38), (57, 36)), bl=leg((30, 40), (29, 49), (28, 57)),
          fa=arm((36, 29), (31, 33), (30, 29)), ba=arm((29, 29), (24, 33), (24, 28))),
        P(fl=leg((34, 41), (38, 48), (38, 56)), fa=arm((35, 30), (33, 35), (34, 32)), ba=arm((29, 30), (26, 35), (27, 32))),
    ], 15, False)
    # Jump: crouch, rise, fall
    A["jump"] = ([
        P(dy=4, hip=(32, 45), neck=(32, 33), head=(33, 23), fl=leg((34, 45), (38, 51), (36, 58)), bl=leg((30, 45), (26, 52), (28, 58)),
          fa=arm((35, 34), (33, 41), (35, 46)), ba=arm((29, 34), (26, 40), (27, 45))),
        P(fl=leg((34, 41), (37, 46), (34, 50)), bl=leg((30, 41), (27, 47), (27, 52)), fa=arm((35, 30), (37, 24), (36, 17)), ba=arm((29, 30), (26, 25), (26, 18))),
        P(fl=leg((34, 41), (39, 46), (40, 52)), bl=leg((30, 41), (26, 46), (24, 51)), fa=arm((35, 30), (39, 25), (43, 22)), ba=arm((29, 30), (24, 26), (20, 23))),
    ], 10, False)
    A["jump_kick"] = ([
        P(neck=(33, 29), head=(34, 19), fl=leg((34, 41), (43, 43), (53, 47)), bl=leg((30, 41), (28, 47), (25, 51)),
          fa=arm((35, 30), (31, 34), (30, 30)), ba=arm((29, 30), (25, 33), (24, 29))),
        P(neck=(33, 29), head=(34, 19), fl=leg((34, 41), (44, 44), (55, 48)), bl=leg((30, 41), (28, 47), (25, 51)),
          fa=arm((35, 30), (31, 34), (30, 30)), ba=arm((29, 30), (25, 33), (24, 29))),
    ], 12, False)
    # Flying shoulder tackle / running attack
    A["run_attack"] = ([
        P(dx=2, neck=(38, 31), head=(41, 22), hip=(32, 41), fa=arm((39, 32), (44, 28), (46, 22)), ba=arm((33, 32), (30, 38), (32, 42)),
          fl=leg((34, 41), (38, 47), (40, 54)), bl=leg((30, 41), (25, 46), (20, 50))),
        P(dx=2, neck=(39, 32), head=(42, 23), fa=arm((40, 33), (46, 30), (48, 24)), ba=arm((34, 33), (31, 39), (33, 43)),
          fl=leg((35, 42), (40, 46), (44, 52)), bl=leg((31, 42), (24, 45), (18, 48))),
    ], 12, False)
    A["dash"] = ([
        P(dx=1, neck=(36, 30), head=(38, 21), fa=arm((37, 31), (33, 36), (32, 40)), ba=arm((31, 31), (28, 36), (26, 40)),
          fl=leg((35, 41), (42, 48), (47, 57)), bl=leg((31, 41), (24, 49), (18, 57))),
    ], 8, False)
    # Hurt
    A["hurt"] = ([
        P(dx=-1, neck=(30, 29), head=(29, 19), eyes="shut", mouth="open", fa=arm((33, 30), (36, 27), (40, 24)), ba=arm((27, 30), (25, 27), (28, 23))),
        P(dx=-2, neck=(29, 30), head=(27, 21), eyes="shut", mouth="open", fa=arm((32, 31), (35, 29), (39, 27)), ba=arm((26, 31), (23, 29), (25, 25))),
    ], 12, False)
    # Falling backwards in the air
    A["fall"] = ([
        P(hip=(30, 38), neck=(22, 30), head=(18, 22), eyes="shut", mouth="open", fa=arm((26, 31), (31, 26), (36, 22)), ba=arm((20, 31), (18, 24), (22, 19)),
          fl=leg((32, 38), (41, 40), (48, 46)), bl=leg((28, 38), (36, 43), (42, 50))),
        P(hip=(30, 40), neck=(20, 36), head=(14, 30), eyes="shut", mouth="open", fa=arm((24, 37), (30, 32), (36, 30)), ba=arm((18, 37), (15, 30), (19, 26)),
          fl=leg((32, 40), (42, 42), (50, 46)), bl=leg((28, 40), (37, 45), (44, 50))),
    ], 8, False)
    # Lying on the ground (feet toward +x)
    A["lying"] = ([
        P(hip=(34, 53), neck=(22, 52), head=(14, 50), eyes="shut", mouth="flat", order=["ba", "bl", "torso", "fl", "head", "fa"],
          fa=arm((24, 50), (30, 46), (36, 48)), ba=arm((22, 54), (28, 56), (34, 56)),
          fl=leg((36, 51), (44, 50), (52, 51)), bl=leg((36, 55), (44, 55), (52, 55))),
    ], 4, True)
    A["getup"] = ([
        P(hip=(32, 50), neck=(26, 42), head=(26, 33), fa=arm((28, 43), (34, 47), (40, 52)), ba=arm((24, 43), (22, 50), (24, 56)),
          fl=leg((34, 50), (42, 50), (44, 58)), bl=leg((30, 50), (26, 55), (22, 58))),
        P(dy=4, hip=(32, 45), neck=(31, 34), head=(32, 24), fl=leg((34, 45), (38, 51), (36, 58)), bl=leg((30, 45), (27, 52), (28, 58)),
          fa=arm((34, 35), (33, 42), (36, 47)), ba=arm((28, 35), (25, 41), (27, 45))),
    ], 8, False)
    # Grab hold / grabbed
    A["grab"] = ([
        P(dx=1, neck=(34, 29), head=(35, 19), fa=arm((36, 30), (42, 32), (48, 30)), ba=arm((30, 30), (38, 31), (46, 32))),
        P(dx=1, dy=1, neck=(34, 30), head=(35, 20), fa=arm((36, 31), (42, 33), (48, 31)), ba=arm((30, 31), (38, 32), (46, 33))),
    ], 4, True)
    A["grabbed"] = ([
        P(neck=(32, 29), head=(33, 20), eyes="shut", mouth="open", fa=arm((35, 30), (33, 37), (34, 44)), ba=arm((29, 30), (27, 37), (26, 44)),
          fl=leg((34, 41), (36, 49), (34, 57)), bl=leg((30, 41), (28, 49), (30, 57))),
    ], 4, True)
    A["throw"] = ([
        P(dx=1, neck=(34, 29), head=(35, 19), fa=arm((36, 30), (42, 32), (48, 30)), ba=arm((30, 30), (38, 31), (46, 32))),
        P(dx=-2, neck=(29, 30), head=(28, 20), fa=arm((33, 31), (28, 26), (22, 22)), ba=arm((27, 31), (24, 26), (20, 24)),
          fl=leg((34, 42), (40, 48), (44, 58)), bl=leg((30, 42), (26, 50), (24, 58))),
        P(dx=3, neck=(37, 30), head=(39, 21), fa=arm((38, 31), (48, 33), (58, 36)), ba=arm((32, 31), (42, 33), (52, 36)),
          fl=leg((36, 42), (44, 49), (48, 58)), bl=leg((30, 42), (25, 50), (20, 58))),
    ], 12, False)
    A["grab_punch"] = ([
        P(dx=1, neck=(34, 29), head=(35, 19), fa=arm((36, 30), (30, 34), (28, 30)), ba=arm((30, 30), (38, 31), (46, 32))),
        P(dx=2, neck=(35, 29), head=(36, 19), fa=arm((37, 30), (45, 30), (53, 30)), ba=arm((31, 30), (39, 31), (47, 32))),
    ], 16, False)
    # Special: crouch charge then explosive burst
    A["special"] = ([
        P(dy=3, hip=(32, 44), neck=(31, 33), head=(32, 23), eyes="shut", fl=leg((34, 44), (38, 50), (36, 58)), bl=leg((30, 44), (26, 51), (28, 58)),
          fa=arm((34, 34), (30, 40), (30, 45)), ba=arm((28, 34), (24, 40), (24, 45))),
        P(dy=3, hip=(32, 44), neck=(31, 33), head=(32, 23), eyes="shut", fl=leg((34, 44), (38, 50), (36, 58)), bl=leg((30, 44), (26, 51), (28, 58)),
          fa=arm((34, 34), (29, 39), (28, 44)), ba=arm((28, 34), (23, 39), (22, 44))),
        P(dy=-2, neck=(32, 27), head=(33, 17), mouth="open", fa=arm((35, 28), (44, 24), (54, 20)), ba=arm((29, 28), (20, 24), (10, 20)),
          fl=leg((34, 39), (40, 46), (44, 56)), bl=leg((30, 39), (24, 46), (20, 56))),
        P(dy=-1, neck=(32, 28), head=(33, 18), mouth="open", fa=arm((35, 29), (45, 28), (56, 28)), ba=arm((29, 29), (19, 28), (8, 28)),
          fl=leg((34, 40), (40, 47), (44, 57)), bl=leg((30, 40), (24, 47), (20, 57))),
    ], 12, False)
    A["ground_stomp"] = ([
        P(dy=-1, fl=leg((34, 40), (40, 34), (44, 42)), bl=leg((30, 40), (28, 49), (28, 57)), fa=arm((35, 29), (31, 33), (30, 29)), ba=arm((29, 29), (25, 33), (26, 29))),
        P(dy=2, hip=(32, 43), neck=(33, 31), head=(34, 21), fl=leg((34, 43), (42, 48), (48, 58)), bl=leg((30, 43), (27, 51), (26, 58)),
          fa=arm((35, 32), (38, 38), (42, 43)), ba=arm((29, 32), (26, 37), (27, 42))),
    ], 12, False)
    A["pickup"] = ([
        P(dy=5, hip=(32, 46), neck=(34, 35), head=(36, 26), fl=leg((34, 46), (39, 52), (38, 58)), bl=leg((30, 46), (25, 53), (26, 58)),
          fa=arm((36, 36), (41, 43), (46, 50)), ba=arm((30, 36), (29, 42), (30, 48))),
    ], 8, False)
    A["weapon_idle"] = ([
        P(fa=arm((35, 30), (38, 36), (42, 39)), ba=arm((29, 30), (27, 36), (26, 42))),
        P(dy=1, fa=arm((35, 31), (38, 37), (42, 40)), ba=arm((29, 31), (27, 37), (26, 43))),
    ], 4, True)
    A["weapon_swing"] = ([
        P(dx=-2, neck=(30, 30), head=(30, 20), fa=arm((33, 31), (28, 24), (24, 16)), ba=arm((27, 31), (24, 36), (26, 32))),
        P(dx=-1, neck=(31, 30), head=(31, 20), fa=arm((34, 31), (33, 22), (34, 13)), ba=arm((28, 31), (25, 36), (27, 32))),
        P(dx=4, dy=1, neck=(37, 30), head=(38, 20), fa=arm((38, 31), (47, 30), (56, 30)), ba=arm((31, 31), (28, 36), (30, 32)),
          fl=leg((36, 42), (42, 49), (46, 58)), bl=leg((30, 42), (26, 50), (22, 58))),
        P(dx=3, dy=1, neck=(36, 30), head=(37, 20), fa=arm((37, 31), (45, 34), (52, 38)), ba=arm((31, 31), (28, 36), (30, 32)),
          fl=leg((36, 42), (42, 49), (46, 58)), bl=leg((30, 42), (26, 50), (22, 58))),
    ], 15, False)
    A["throw_item"] = ([
        P(dx=-1, neck=(31, 30), head=(31, 20), fa=arm((34, 31), (30, 25), (28, 18)), ba=arm((28, 31), (25, 36), (27, 32))),
        P(dx=3, neck=(36, 30), head=(37, 20), fa=arm((37, 31), (46, 29), (56, 27)), ba=arm((31, 31), (28, 36), (30, 32)),
          fl=leg((36, 42), (42, 49), (46, 58)), bl=leg((30, 42), (26, 50), (22, 58))),
    ], 12, False)
    A["victory"] = ([
        P(mouth="open", fa=arm((35, 30), (39, 24), (38, 16)), ba=arm((29, 30), (25, 24), (26, 16))),
        P(dy=-2, mouth="open", fa=arm((35, 28), (40, 21), (40, 12)), ba=arm((29, 28), (24, 21), (24, 12)), fl=leg((34, 39), (36, 46), (36, 56)), bl=leg((30, 39), (28, 46), (28, 56))),
    ], 4, True)
    A["talk"] = ([
        P(mouth="open", fa=arm((35, 30), (39, 34), (42, 31))),
        P(dy=1, mouth="flat", fa=arm((35, 31), (39, 35), (43, 32))),
        P(mouth="open", fa=arm((35, 30), (38, 34), (40, 30))),
        P(dy=1, mouth="flat"),
    ], 5, True)
    A["block"] = ([
        P(fa=arm((35, 30), (39, 27), (37, 21)), ba=arm((29, 30), (33, 28), (32, 22))),
    ], 4, True)
    A["taunt"] = ([
        P(fa=arm((35, 30), (42, 33), (46, 28)), ba=arm((29, 30), (26, 35), (28, 31))),
        P(dy=1, fa=arm((35, 31), (42, 33), (47, 30)), ba=arm((29, 31), (26, 36), (28, 32))),
        P(fa=arm((35, 30), (42, 33), (46, 26)), ba=arm((29, 30), (26, 35), (28, 31))),
    ], 5, True)
    return A

ANIMS = build_animations()
FULL_SET = list(ANIMS.keys())
ENEMY_SET = ["idle", "walk", "run", "punch1", "punch2", "kick", "heavy", "jump", "jump_kick", "run_attack", "hurt", "fall", "lying",
             "getup", "grab", "grabbed", "throw", "grab_punch", "weapon_idle", "weapon_swing", "throw_item", "taunt", "pickup", "block", "talk", "special", "uppercut", "spin_kick", "ground_stomp"]
NPC_SET = ["idle", "walk", "talk", "victory", "taunt"]

# ---------------------------------------------------------------------------
# Character specs
# ---------------------------------------------------------------------------
def spec(**kw):
    d = dict(
        skin=(232, 184, 140), skin_shade=(196, 140, 100),
        hair=(48, 30, 36), hair_style="short",
        shirt=(200, 60, 60), shirt_shade=(150, 40, 45), shirt_style="jacket", under=(240, 240, 235),
        sleeves=True, pants=(60, 80, 150), pants_shade=(40, 55, 110), shoes=(240, 240, 240), shoe_shade=(180, 180, 190),
        gloves=None, glasses=False, hat=None, hat_color=(40, 40, 40), bandana=None, mask=None, beard=None,
        torso_w=12, limb_w=4, head_r=7, scale=1.0, stance=0, hunch=0, belt=(40, 30, 30), apron=None,
        anims=FULL_SET, mustache=False, eye=(30, 20, 30), stripe=None,
    )
    d.update(kw)
    # Remember what this character asked for explicitly, so the build applied below can
    # fill in the rest without overriding a deliberate choice.
    d["_explicit"] = set(kw.keys())
    return d

CHARACTERS = {
    # ---- Player ----
    "kip": spec(skin=(234, 190, 150), hair=(40, 28, 40), hair_style="spiky", shirt=(214, 58, 68), shirt_shade=(160, 38, 52),
                under=(246, 240, 226), pants=(52, 70, 140), shoes=(246, 246, 246), shoe_shade=(160, 170, 200)),
    # ---- Pigeon Gang (Ferry Row) ----
    "pigeon_grunt": spec(skin=(226, 176, 132), hair=(70, 60, 60), hair_style="beanie", hat_color=(90, 96, 110), shirt=(126, 134, 150), shirt_shade=(88, 94, 108),
                         shirt_style="hoodie", under=(126, 134, 150), pants=(50, 50, 60), shoes=(60, 60, 70), shoe_shade=(30, 30, 40), anims=ENEMY_SET),
    "pigeon_rusher": spec(skin=(200, 150, 110), hair=(30, 20, 20), hair_style="cap", hat_color=(150, 160, 180), shirt=(120, 190, 220), shirt_shade=(80, 140, 170),
                          shirt_style="track", under=(120, 190, 220), pants=(120, 190, 220), pants_shade=(80, 140, 170), shoes=(250, 250, 250), shoe_shade=(180, 180, 200), anims=ENEMY_SET,
                          limb_w=3, head_r=6, stripe=(250, 250, 250)),
    # ---- Sweater Gang (Lantern Market) ----
    "sweater_grunt": spec(skin=(240, 200, 170), hair=(180, 120, 60), hair_style="side", shirt=(90, 150, 90), shirt_shade=(60, 110, 60), shirt_style="sweater", under=(90, 150, 90),
                          pants=(180, 160, 120), pants_shade=(140, 120, 90), shoes=(110, 70, 40), shoe_shade=(70, 40, 20), anims=ENEMY_SET, glasses=False, stripe=(220, 200, 120)),
    "sweater_grappler": spec(skin=(210, 160, 120), hair=(60, 40, 30), hair_style="bald", shirt=(160, 80, 120), shirt_shade=(120, 55, 90), shirt_style="sweater", under=(160, 80, 120),
                             pants=(70, 60, 80), pants_shade=(45, 40, 55), shoes=(40, 40, 40), shoe_shade=(20, 20, 20), anims=ENEMY_SET,
                             torso_w=17, limb_w=6, head_r=8, beard=(60, 40, 30), stripe=(240, 220, 150)),
    # ---- Grease Monkeys (Grease Alley) ----
    "grease_weapon": spec(skin=(200, 160, 130), hair=(40, 40, 40), hair_style="bandana", bandana=(220, 60, 50), shirt=(60, 70, 90), shirt_shade=(40, 48, 66), shirt_style="overalls",
                          under=(230, 220, 200), pants=(60, 70, 90), pants_shade=(40, 48, 66), shoes=(90, 60, 40), shoe_shade=(50, 35, 20), anims=ENEMY_SET, gloves=(180, 130, 80)),
    "grease_grunt": spec(skin=(180, 130, 100), hair=(20, 20, 24), hair_style="mohawk", shirt=(40, 40, 46), shirt_shade=(20, 20, 26), shirt_style="vest", under=(200, 200, 200),
                         pants=(60, 60, 60), pants_shade=(35, 35, 35), shoes=(30, 30, 30), shoe_shade=(10, 10, 10), anims=ENEMY_SET, glasses=True),
    # ---- Rust Rats (Rustpile Yard) ----
    "rust_heavy": spec(skin=(220, 180, 150), hair=(150, 90, 40), hair_style="helmet", hat_color=(190, 120, 40), shirt=(140, 90, 60), shirt_shade=(100, 60, 40), shirt_style="vest",
                       under=(180, 60, 40), pants=(70, 60, 50), pants_shade=(45, 40, 32), shoes=(50, 40, 30), shoe_shade=(25, 20, 15), anims=ENEMY_SET,
                       torso_w=18, limb_w=6, head_r=8, mask=(80, 80, 90)),
    "rust_ranged": spec(skin=(210, 170, 140), hair=(90, 60, 40), hair_style="cap", hat_color=(180, 70, 40), shirt=(200, 130, 60), shirt_shade=(150, 90, 40), shirt_style="track",
                        under=(200, 130, 60), pants=(80, 70, 60), pants_shade=(55, 48, 40), shoes=(100, 80, 60), shoe_shade=(60, 45, 30), anims=ENEMY_SET, limb_w=3, head_r=6, gloves=(120, 120, 130)),
    # ---- The Cleaners (Starch's Laundromat) ----
    "cleaner_elite": spec(skin=(230, 190, 160), hair=(30, 30, 40), hair_style="slick", shirt=(238, 238, 242), shirt_shade=(178, 178, 192), shirt_style="shirt", under=(240, 240, 240),
                          pants=(30, 30, 40), pants_shade=(15, 15, 22), shoes=(20, 20, 25), shoe_shade=(5, 5, 10), anims=ENEMY_SET, glasses=True, apron=(120, 170, 230)),
    "cleaner_grappler": spec(skin=(190, 140, 110), hair=(20, 20, 20), hair_style="bald", shirt=(238, 238, 242), shirt_shade=(178, 178, 192), shirt_style="shirt", under=(240, 240, 240),
                             pants=(30, 30, 40), pants_shade=(15, 15, 22), shoes=(20, 20, 25), shoe_shade=(5, 5, 10), anims=ENEMY_SET, torso_w=17, limb_w=6, head_r=8, apron=(120, 170, 230), glasses=True),
    # ---- Boss ----
    "big_starch": spec(skin=(236, 196, 170), hair=(228, 226, 232), hair_style="flattop", shirt=(238, 236, 244), shirt_shade=(176, 176, 196), shirt_style="suit", under=(70, 130, 220),
                       pants=(226, 224, 234), pants_shade=(164, 164, 186), shoes=(232, 230, 240), shoe_shade=(150, 150, 172), anims=ENEMY_SET,
                       torso_w=20, limb_w=7, head_r=9, mustache=True, scale=1.0, belt=(60, 50, 40), gloves=(250, 250, 250)),
    # ---- NPCs ----
    "dez": spec(skin=(120, 80, 60), skin_shade=(90, 55, 40), hair=(20, 16, 16), hair_style="afro", shirt=(250, 200, 60), shirt_shade=(200, 150, 40), shirt_style="shirt",
                under=(250, 200, 60), pants=(40, 40, 50), shoes=(240, 100, 60), shoe_shade=(180, 60, 40), anims=NPC_SET),
    "auntie_mae": spec(skin=(210, 160, 130), hair=(200, 200, 210), hair_style="bun", shirt=(220, 120, 160), shirt_shade=(170, 80, 120), shirt_style="shirt", under=(220, 120, 160),
                       pants=(120, 80, 100), shoes=(80, 50, 60), shoe_shade=(50, 30, 40), anims=NPC_SET, apron=(250, 250, 240), head_r=7),
    "vic": spec(skin=(240, 200, 170), hair=(150, 60, 40), hair_style="cap", hat_color=(60, 120, 200), shirt=(60, 120, 200), shirt_shade=(40, 85, 150), shirt_style="vest", under=(250, 250, 250),
                pants=(40, 40, 60), shoes=(50, 50, 60), shoe_shade=(20, 20, 30), anims=NPC_SET),
    "odell": spec(skin=(160, 110, 80), hair=(230, 230, 230), hair_style="bald", shirt=(242, 240, 234), shirt_shade=(186, 184, 178), shirt_style="gi", under=(242, 240, 234),
                  pants=(236, 234, 228), pants_shade=(178, 176, 170), shoes=(160, 110, 80), shoe_shade=(120, 80, 60), anims=NPC_SET, belt=(30, 30, 30), beard=(230, 230, 230)),
    "marisol": spec(skin=(220, 170, 140), hair=(90, 40, 30), hair_style="long", shirt=(150, 90, 200), shirt_shade=(110, 60, 150), shirt_style="sweater", under=(150, 90, 200),
                    pants=(50, 50, 70), shoes=(120, 80, 60), shoe_shade=(80, 50, 40), anims=NPC_SET, glasses=True),
    "pops": spec(skin=(200, 150, 120), hair=(180, 180, 180), hair_style="side", shirt=(120, 90, 70), shirt_shade=(85, 60, 45), shirt_style="vest", under=(200, 190, 170),
                 pants=(60, 60, 70), shoes=(70, 50, 40), shoe_shade=(40, 30, 20), anims=NPC_SET, beard=(180, 180, 180), torso_w=14),
    "student": spec(skin=(235, 195, 165), hair=(60, 40, 30), hair_style="short", shirt=(250, 250, 250), shirt_shade=(200, 200, 210), shirt_style="shirt", under=(250, 250, 250),
                    pants=(40, 60, 100), shoes=(40, 40, 40), shoe_shade=(20, 20, 20), anims=NPC_SET, head_r=6, limb_w=3),
    "worker": spec(skin=(190, 140, 110), hair=(40, 30, 30), hair_style="helmet", hat_color=(240, 200, 40), shirt=(240, 140, 40), shirt_shade=(190, 100, 30), shirt_style="vest",
                   under=(240, 140, 40), pants=(70, 70, 90), shoes=(90, 60, 40), shoe_shade=(50, 35, 20), anims=NPC_SET, torso_w=14),
    "performer": spec(skin=(230, 190, 160), hair=(220, 60, 120), hair_style="mohawk", shirt=(60, 200, 200), shirt_shade=(40, 150, 150), shirt_style="jacket", under=(250, 250, 100),
                      pants=(200, 60, 120), pants_shade=(150, 40, 90), shoes=(250, 250, 250), shoe_shade=(180, 180, 200), anims=NPC_SET, glasses=True),
    "rumor_kid": spec(skin=(200, 160, 130), hair=(90, 60, 40), hair_style="cap", hat_color=(200, 60, 60), shirt=(80, 180, 100), shirt_shade=(50, 130, 70), shirt_style="shirt", under=(80, 180, 100),
                      pants=(60, 80, 150), shoes=(250, 250, 250), shoe_shade=(180, 180, 200), anims=NPC_SET, head_r=6, limb_w=3, scale=0.9),
    "old_ferry": spec(skin=(220, 180, 150), hair=(200, 200, 200), hair_style="cap", hat_color=(40, 60, 90), shirt=(40, 60, 90), shirt_shade=(25, 40, 65), shirt_style="sweater", under=(40, 60, 90),
                      pants=(80, 70, 60), shoes=(60, 40, 30), shoe_shade=(35, 25, 15), anims=NPC_SET, beard=(200, 200, 200)),
    # ---- The Commuters (Metro Line / Bellwater) ----
    "commuter_grunt": spec(skin=(214, 168, 132), hair=(52, 44, 40), hair_style="beanie", hat_color=(58, 74, 96),
                           shirt=(72, 92, 120), shirt_shade=(48, 62, 84), shirt_style="hoodie", under=(72, 92, 120),
                           pants=(46, 48, 58), shoes=(210, 208, 200), shoe_shade=(150, 150, 158), anims=ENEMY_SET),
    "commuter_rusher": spec(skin=(228, 184, 148), hair=(40, 34, 30), hair_style="cap", hat_color=(220, 196, 60),
                            shirt=(232, 200, 64), shirt_shade=(178, 150, 40), shirt_style="track", under=(232, 200, 64),
                            pants=(52, 56, 70), pants_shade=(34, 38, 50), shoes=(246, 246, 246), shoe_shade=(170, 172, 190),
                            anims=ENEMY_SET, limb_w=3, head_r=6, stripe=(60, 62, 76)),
    "commuter_grappler": spec(skin=(176, 128, 96), hair=(28, 24, 24), hair_style="bald", shirt=(58, 70, 92),
                              shirt_shade=(38, 46, 64), shirt_style="vest", under=(206, 206, 200),
                              pants=(40, 42, 52), shoes=(34, 34, 40), shoe_shade=(16, 16, 20), anims=ENEMY_SET,
                              torso_w=17, limb_w=6, head_r=8, beard=(28, 24, 24)),
    "commuter_heavy": spec(skin=(206, 160, 126), hair=(60, 52, 48), hair_style="cap", hat_color=(30, 40, 62),
                           shirt=(34, 46, 72), shirt_shade=(22, 30, 50), shirt_style="suit", under=(200, 176, 70),
                           pants=(30, 34, 46), pants_shade=(18, 22, 32), shoes=(28, 28, 34), shoe_shade=(12, 12, 16),
                           anims=ENEMY_SET, torso_w=18, limb_w=6, head_r=8, mustache=True, mask=(90, 96, 110)),
    "commuter_ranged": spec(skin=(238, 196, 166), hair=(190, 90, 140), hair_style="long", shirt=(120, 80, 176),
                            shirt_shade=(86, 56, 130), shirt_style="jacket", under=(240, 232, 200),
                            pants=(64, 60, 84), shoes=(238, 120, 90), shoe_shade=(180, 80, 60), anims=ENEMY_SET,
                            limb_w=3, head_r=6, glasses=True),
    # ---- New district NPCs ----
    "nadia": spec(skin=(150, 100, 72), skin_shade=(112, 70, 50), hair=(24, 20, 20), hair_style="bun",
                  shirt=(96, 176, 168), shirt_shade=(64, 132, 126), shirt_style="shirt", under=(96, 176, 168),
                  pants=(58, 54, 70), shoes=(200, 130, 70), shoe_shade=(150, 90, 45), anims=NPC_SET, apron=(238, 232, 216)),
    "bex": spec(skin=(226, 178, 140), hair=(220, 216, 210), hair_style="side", shirt=(228, 226, 220),
                shirt_shade=(176, 174, 168), shirt_style="gi", under=(228, 226, 220), pants=(222, 220, 214),
                pants_shade=(170, 168, 162), shoes=(150, 110, 80), shoe_shade=(110, 76, 54), anims=NPC_SET,
                belt=(150, 40, 60), glasses=True),
    "roof_kid": spec(skin=(216, 172, 140), hair=(70, 50, 36), hair_style="beanie", hat_color=(200, 80, 90),
                     shirt=(90, 160, 210), shirt_shade=(60, 116, 158), shirt_style="hoodie", under=(90, 160, 210),
                     pants=(58, 62, 78), shoes=(240, 240, 240), shoe_shade=(176, 176, 190), anims=NPC_SET,
                     head_r=6, limb_w=3, scale=0.92),
    "train_guard": spec(skin=(196, 148, 116), hair=(40, 36, 34), hair_style="helmet", hat_color=(40, 54, 80),
                        shirt=(46, 60, 88), shirt_shade=(30, 40, 62), shirt_style="vest", under=(214, 198, 90),
                        pants=(44, 46, 56), shoes=(50, 44, 40), shoe_shade=(28, 24, 22), anims=NPC_SET, torso_w=14),
    "laundry_lady": spec(skin=(240, 205, 180), hair=(80, 50, 40), hair_style="bun", shirt=(200, 220, 240), shirt_shade=(150, 170, 200), shirt_style="shirt", under=(200, 220, 240),
                         pants=(60, 60, 80), shoes=(120, 90, 80), shoe_shade=(80, 60, 50), anims=NPC_SET, apron=(250, 250, 250)),
}

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------
def light(c, f=1.22):
    """Lit side of a colour. The scene's key light is up and to the left."""
    return (min(255, int(c[0] * f)), min(255, int(c[1] * f)), min(255, int(c[2] * f)), 255)

def shade(c, f=0.72):
    return (int(c[0] * f), int(c[1] * f), int(c[2] * f), 255)

def rgba(c):
    return (c[0], c[1], c[2], 255) if len(c) == 3 else c

def rect(d, xy, fill):
    """Rectangle that tolerates inverted coordinates (poses can turn the torso upside down)."""
    x0, y0, x1, y1 = xy
    d.rectangle([min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)], fill=fill)

def draw_capsule(d, a, b, w, color):
    d.line([a, b], fill=color, width=w)
    r = w / 2.0
    for p in (a, b):
        d.ellipse([p[0] - r, p[1] - r, p[0] + r - 1, p[1] + r - 1], fill=color)

def draw_limb(d, pts, w, colors, outline_pass, shadec=None):
    """pts: 3 joints; colors: (upper, lower). Draw with outline or fill."""
    if outline_pass:
        draw_capsule(d, pts[0], pts[1], w + 2, OUTLINE)
        draw_capsule(d, pts[1], pts[2], w + 2, OUTLINE)
        return
    up, lo = colors
    # The forearm is slimmer than the upper arm. At a uniform width a limb hanging across
    # the torso reads as a slab rather than as an arm, which is what made the bare
    # forearms look like blobs of skin stuck to the chest.
    wl = max(2, w - 1)
    draw_capsule(d, pts[0], pts[1], w, shade(up))
    draw_capsule(d, pts[1], pts[2], wl, shade(lo))
    o = (0, -1)
    draw_capsule(d, (pts[0][0] + o[0], pts[0][1] + o[1]), (pts[1][0] + o[0], pts[1][1] + o[1]), max(1, w - 1), rgba(up))
    draw_capsule(d, (pts[1][0] + o[0], pts[1][1] + o[1]), (pts[2][0] + o[0], pts[2][1] + o[1]), max(1, wl - 1), rgba(lo))
    # Always break the limb at the elbow. A sleeve cuff is the obvious case, but a bare
    # arm needs it more: a thick limb in one flat skin tone hanging across the chest is
    # the thing that reads as a blob of nothing rather than as an arm.
    ex, ey = pts[1]
    r = max(1, wl // 2)
    joint = shade(up, 0.55) if tuple(up[:3]) != tuple(lo[:3]) else shade(lo, 0.78)
    d.ellipse([ex - r - 1, ey - r - 1, ex + r, ey + r], fill=joint)

def torso_poly(pose, tw):
    hip = pose["hip"]; neck = pose["neck"]
    hw = tw / 2.0
    ww = hw * 0.68 + 1.0          # waist noticeably narrower than the shoulders
    my = neck[1] + (hip[1] - neck[1]) * 0.55
    mw = hw * 0.86
    mx = neck[0] + (hip[0] - neck[0]) * 0.55
    return [(neck[0] - hw + 1, neck[1] - 1), (neck[0] + hw - 1, neck[1] - 1),
            (mx + mw, my), (hip[0] + ww, hip[1] + 1),
            (hip[0] - ww, hip[1] + 1), (mx - mw, my)]

def draw_torso(d, pose, sp, outline_pass):
    tw = sp["torso_w"]
    poly = torso_poly(pose, tw)
    if outline_pass:
        cxp = sum(p[0] for p in poly) / len(poly)
        cyp = sum(p[1] for p in poly) / len(poly)
        big = [(x + (1 if x > cxp else -1), y + (1 if y > cyp else -1)) for (x, y) in poly]
        d.polygon(big, fill=OUTLINE)
        return
    shirt = rgba(sp["shirt"]); sh2 = rgba(sp["shirt_shade"]); under = rgba(sp["under"])
    d.polygon(poly, fill=shirt)
    # Shoulder line and the left flank catch the key light; the right flank falls away.
    d.line([poly[1], poly[2]], fill=sh2)
    d.line([poly[2], poly[3]], fill=sh2)
    d.line([poly[0], poly[1]], fill=light(sp["shirt"]))
    d.line([poly[0], poly[5]], fill=light(sp["shirt"]))
    # shade bottom third
    hip = pose["hip"]; neck = pose["neck"]
    hw = tw / 2.0
    ww = hw * 0.68 + 1.0
    y1 = int(neck[1] + (hip[1] - neck[1]) * 0.62)
    x1 = neck[0] + (hip[0] - neck[0]) * 0.62
    w1 = hw * 0.8
    d.polygon([(x1 - w1, y1), (x1 + w1, y1), (hip[0] + ww, hip[1] + 1), (hip[0] - ww, hip[1] + 1)], fill=sh2)
    style = sp["shirt_style"]
    cx = (neck[0] + hip[0]) // 2
    if style in ("jacket", "vest"):
        # open jacket shows undershirt strip
        rect(d, [cx - 1, neck[1] + 1, cx + 1, hip[1] - 1], fill=under)
        d.line([(cx - 2, neck[1] + 1), (cx - 2, hip[1] - 2)], fill=sh2)
    elif style == "hoodie":
        rect(d, [cx - 1, neck[1] + 2, cx + 1, neck[1] + 5], fill=sh2)
        d.line([(cx - 3, neck[1] + 1), (cx + 3, neck[1] + 1)], fill=sh2)
    elif style == "track":
        stripe = rgba(sp.get("stripe") or (255, 255, 255))
        d.line([(cx - 3, neck[1] + 1), (cx - 3, hip[1])], fill=stripe)
        d.line([(cx + 3, neck[1] + 1), (cx + 3, hip[1])], fill=stripe)
    elif style == "sweater":
        stripe = rgba(sp.get("stripe") or (255, 255, 255))
        for yy in range(neck[1] + 3, hip[1], 4):
            d.line([(neck[0] - hw + 1, yy), (neck[0] + hw - 1, yy)], fill=stripe)
    elif style == "overalls":
        rect(d, [neck[0] - hw + 1, neck[1], neck[0] + hw - 1, neck[1] + 4], fill=under)
        d.line([(cx - 2, neck[1]), (cx - 2, neck[1] + 5)], fill=shirt)
        d.line([(cx + 2, neck[1]), (cx + 2, neck[1] + 5)], fill=shirt)
    elif style == "suit":
        d.polygon([(cx - 4, neck[1]), (cx + 4, neck[1]), (cx, neck[1] + 7)], fill=under)
        d.line([(cx, neck[1] + 1), (cx, neck[1] + 6)], fill=(200, 40, 40, 255))
    elif style == "gi":
        d.line([(cx - 4, neck[1]), (cx + 1, hip[1] - 2)], fill=sh2)
        d.line([(cx + 4, neck[1]), (cx - 1, hip[1] - 2)], fill=sh2)
    elif style == "shirt":
        d.line([(cx, neck[1] + 1), (cx, neck[1] + 4)], fill=sh2)
    # ---- collar, seams, hem -------------------------------------------------
    #
    # Every top used to meet the neck with the straight edge of the torso polygon, so a
    # jacket, a sweater and a suit were the same coloured block in different colours. At
    # this size the neckline is the most identifying part of a garment, and the shoulder
    # seam is what stops the chest and the sleeve reading as one slab.
    dark = shade(sp["shirt"], 0.60)
    ny = neck[1]
    if style in ("jacket", "vest"):
        # notched lapels falling either side of the opening
        d.line([(cx - 3, ny), (cx - 1, ny + 3)], fill=dark)
        d.line([(cx + 3, ny), (cx + 1, ny + 3)], fill=dark)
    elif style == "hoodie":
        # the hood itself, bunched behind the neck. Drawn on the torso so the head, which
        # comes later in the draw order, sits in front of it.
        d.chord([cx - 5, ny - 3, cx + 5, ny + 4], 180, 360, fill=dark)
    elif style == "suit":
        d.line([(cx - 4, ny), (cx - 1, ny + 5)], fill=dark)
        d.line([(cx + 4, ny), (cx + 1, ny + 5)], fill=dark)
    elif style == "overalls":
        pass                      # the bib already reads as its own shape
    elif style == "gi":
        pass                      # the wrap is the neckline
    else:
        # crew neck
        d.arc([cx - 4, ny - 1, cx + 4, ny + 4], 200, 340, fill=dark)

    # Shoulder seams, where a sleeve is set into the body.
    if sp["sleeves"] and style != "vest":
        seam = hw * 0.74
        d.line([(neck[0] - seam, ny), (neck[0] - seam, ny + 3)], fill=dark)
        d.line([(neck[0] + seam, ny), (neck[0] + seam, ny + 3)], fill=dark)

    # A hem, so an open garment ends rather than simply stopping at the waist.
    if style in ("jacket", "hoodie", "vest"):
        d.line([(hip[0] - ww + 1, hip[1] - 2), (hip[0] + ww - 1, hip[1] - 2)], fill=dark)

    if sp.get("apron"):
        ap = rgba(sp["apron"])
        ay = neck[1] + 6
        d.polygon([(cx - hw + 3.5, ay), (cx + hw - 3.5, ay),
                   (hip[0] + hw * 0.6, hip[1] + 1), (hip[0] - hw * 0.6, hip[1] + 1)], fill=ap)
    # belt
    d.line([(hip[0] - hw + 1, hip[1]), (hip[0] + hw - 1, hip[1])], fill=rgba(sp["belt"]))

def draw_head(d, pose, sp, outline_pass, r=None, center=None, portrait=False):
    r = r or sp["head_r"]
    cx, cy = center or pose["head"]
    fd = pose.get("face_dir", 1)
    if outline_pass:
        d.ellipse([cx - r - 1, cy - r - 1, cx + r, cy + r], fill=OUTLINE)
        _draw_hair(d, cx, cy, r, sp, outline=True, fd=fd)
        return
    skin = rgba(sp["skin"]); skin2 = rgba(sp["skin_shade"])
    d.ellipse([cx - r, cy - r, cx + r - 1, cy + r - 1], fill=skin)
    # jaw shade
    d.chord([cx - r, cy - r, cx + r - 1, cy + r - 1], 20, 160, fill=skin2)
    d.ellipse([cx - r, cy - r, cx + r - 1, cy + r - 3], fill=skin)
    # Key light is up and to the left, so the far cheek catches an edge of it.
    d.arc([cx - r, cy - r, cx + r - 1, cy + r - 1], 168, 250, fill=light(sp["skin"]))
    _draw_hair(d, cx, cy, r, sp, outline=False, fd=fd)
    # face
    eye = rgba(sp["eye"])
    ex = cx + (2 if fd > 0 else -3) * (1 if r < 9 else 1.4)
    ex = int(ex)
    # Sit the eyes clear of the fringe. Flush against it they merge into the hair mass and
    # the face reads as blank, which is what it did before.
    ey = cy + 1 if r < 9 else cy - 1
    if pose.get("eyes", "open") == "open":
        # Two pixels wide with a brow above. A single dark pixel is invisible at this size,
        # which is why the cast read as faceless.
        rect(d, [ex, ey, ex + 1, ey + 1], fill=eye)
        far_x = ex - (5 if r >= 9 else 4)
        if fd > 0:
            rect(d, [far_x, ey, far_x, ey + 1], fill=eye)
        # A brow only fits on the larger heads; on a small one it just thickens the fringe.
        if r >= 9:
            rect(d, [ex, ey - 2, ex + 1, ey - 2], fill=rgba(sp["hair"]))
            if fd > 0:
                rect(d, [far_x, ey - 2, far_x, ey - 2], fill=rgba(sp["hair"]))
    elif pose.get("eyes") == "shut":
        d.line([(ex - 1, ey + 1), (ex + 1, ey + 1)], fill=eye)
    if sp.get("glasses") and pose.get("eyes") != "none":
        g = (30, 30, 40, 255)
        if fd > 0:
            rect(d, [ex - 1, ey - 1, ex + 1, ey + 1], fill=g)
            d.line([(ex - 3, ey), (ex - 2, ey)], fill=g)
        else:
            rect(d, [ex - 1, ey - 1, ex + 1, ey + 1], fill=g)
    if pose.get("mouth") == "open" and pose.get("eyes") != "none":
        mx = cx + (2 if fd > 0 else -2)
        rect(d, [mx - 1, cy + 3, mx + 1, cy + 4], fill=(90, 30, 40, 255))
    elif pose.get("eyes") != "none":
        mx = cx + (2 if fd > 0 else -2)
        d.line([(mx - 1, cy + 3), (mx + 1, cy + 3)], fill=skin2)
    if sp.get("mustache") and fd > 0 and pose.get("eyes") != "none":
        rect(d, [cx, cy + 2, cx + r - 2, cy + 2], fill=rgba(sp["hair"]))
    if sp.get("beard") and pose.get("eyes") != "none":
        b = rgba(sp["beard"])
        d.chord([cx - r + 1, cy - r + 2, cx + r - 2, cy + r], 30, 150, fill=b)
        if pose.get("mouth") == "open":
            mx = cx + (2 if fd > 0 else -2)
            rect(d, [mx - 1, cy + 3, mx + 1, cy + 4], fill=(90, 30, 40, 255))
    if sp.get("mask"):
        m = rgba(sp["mask"])
        rect(d, [cx - r + 1, cy - 1, cx + r - 2, cy + r - 2], fill=m)
        d.line([(cx - r + 3, cy + 1), (cx + r - 4, cy + 1)], fill=OUTLINE)
        d.line([(cx - r + 3, cy + 3), (cx + r - 4, cy + 3)], fill=OUTLINE)

def _draw_hair(d, cx, cy, r, sp, outline, fd):
    style = sp["hair_style"]
    col = OUTLINE if outline else rgba(sp["hair"])
    o = 1 if outline else 0
    top = cy - r
    if style == "bald":
        return
    if style in ("short", "side", "slick", "spiky", "afro", "long", "bun", "mohawk", "flattop"):
        # cap of hair: top of the circle down to eye level on the back side
        if style == "afro":
            d.ellipse([cx - r - 2 - o, top - 3 - o, cx + r + 1 + o, cy + 1 + o], fill=col)
            return
        if style == "flattop":
            # boxy flat-top: hair cap hugging the skull plus a flat slab on top
            d.chord([cx - r - o, top - o, cx + r - 1 + o, cy + r - 4 + o], 180, 360, fill=col)
            rect(d, [cx - r + 1 - o, top - 4 - o, cx + r - 2 + o, top + 1], fill=col)
            if not outline:
                rect(d, [cx - r + 1, top - 4, cx + r - 2, top - 3], fill=shade(sp["hair"], 1.08))
            return
        # The cap used to reach the middle of the head, leaving barely seven pixels of
        # face and burying the eyes in the fringe. Shallower gives the face room to read.
        d.chord([cx - r - o, top - o, cx + r - 1 + o, cy + r - 4 + o], 180, 360, fill=col)
        rect(d, [cx - r - o, cy - 2, cx - r + 2 + o, cy + 1 + o], fill=col) if fd > 0 else rect(d, [cx + r - 3 - o, cy - 2, cx + r - 1 + o, cy + 1 + o], fill=col)
        if style == "spiky":
            for i, sx in enumerate((cx - 4, cx - 1, cx + 2, cx + 5)):
                d.polygon([(sx - 1 - o, top + 1), (sx + 1 + o, top + 1), (sx + (1 if i % 2 else -1), top - 3 - o)], fill=col)
        elif style == "side":
            rect(d, [cx - r - o, top + 1, cx + 2, top + 3], fill=col)
        elif style == "slick":
            rect(d, [cx - r - 1 - o, top + 1, cx + r - 2, top + 2], fill=col)
        elif style == "long":
            rect(d, [cx - r - 1 - o, cy - 2, cx - r + 2 + o, cy + r + 2 + o], fill=col)
        elif style == "bun":
            d.ellipse([cx - r - 3 - o, top - 1 - o, cx - r + 2 + o, top + 4 + o], fill=col)
        elif style == "mohawk":
            rect(d, [cx - 2 - o, top - 5 - o, cx + 2 + o, top + 2], fill=col)
        return
    # hats
    hc = OUTLINE if outline else rgba(sp["hat_color"])
    if style == "cap":
        d.chord([cx - r - o, top - 1 - o, cx + r - 1 + o, cy + r - 2 + o], 180, 360, fill=hc)
        if fd > 0:
            rect(d, [cx + 1, cy - r + 3 - o, cx + r + 3 + o, cy - r + 4 + o], fill=hc)
        else:
            rect(d, [cx - r - 4 - o, cy - r + 3 - o, cx - 1, cy - r + 4 + o], fill=hc)
    elif style == "beanie":
        d.chord([cx - r - o, top - 2 - o, cx + r - 1 + o, cy + r - 1 + o], 180, 360, fill=hc)
        rect(d, [cx - r - o, cy - 3 - o, cx + r - 1 + o, cy - 1 + o], fill=hc if outline else shade(sp["hat_color"], 0.8))
    elif style == "bandana":
        d.chord([cx - r - o, top - o, cx + r - 1 + o, cy + r - 1 + o], 180, 360, fill=col)
        bc = OUTLINE if outline else rgba(sp["bandana"])
        rect(d, [cx - r - o, cy - 3 - o, cx + r - 1 + o, cy - 1 + o], fill=bc)
        d.polygon([(cx - r - 1 - o, cy - 2), (cx - r - 5 - o, cy + 3 + o), (cx - r + 1, cy)], fill=bc)
    elif style == "helmet":
        d.chord([cx - r - 1 - o, top - 2 - o, cx + r + o, cy + r - 1 + o], 180, 360, fill=hc)
        rect(d, [cx - r - 2 - o, cy - 2 - o, cx + r + 1 + o, cy - 1 + o], fill=hc)

def draw_shoe(d, foot, sp, outline_pass, w):
    x, y = foot
    if outline_pass:
        rect(d, [x - 3, y - 2, x + 3, y + 1], fill=OUTLINE)
        return
    rect(d, [x - 2, y - 1, x + 2, y], fill=rgba(sp["shoes"]))
    d.line([(x - 2, y), (x + 2, y)], fill=rgba(sp["shoe_shade"]))

def draw_hand(d, hand, sp, outline_pass, w):
    x, y = hand
    # Never wider than the forearm, which is now w-1.
    r = 2 if w <= 5 else 3
    col = rgba(sp["gloves"]) if sp.get("gloves") else rgba(sp["skin"])
    if outline_pass:
        d.ellipse([x - r - 1, y - r - 1, x + r, y + r], fill=OUTLINE)
        return
    d.ellipse([x - r, y - r, x + r - 1, y + r - 1], fill=col)

def shape_pose(pose, sp):
    """Apply the build's stance and hunch.

    Torso width and limb thickness come from the spec and are read directly by the
    drawing code. Stance and hunch have to move joints, so they are applied here, to a
    copy: the pose dictionaries are shared by every character in the game.
    """
    st = int(sp.get("stance", 0))
    hu = int(sp.get("hunch", 0))
    # Arms hang from the edge of the shoulder, so widening the torso has to carry them
    # outward with it. Without this a broad build kept its arms at the old narrow spacing
    # and they hung across the middle of the chest as a slab of bare forearm.
    spread = int(round((sp.get("torso_w", 12) - 12) / 2.0))
    if st == 0 and hu == 0 and spread == 0:
        return pose
    out = dict(pose)
    if spread:
        for key, sign in (("fa", 1), ("ba", -1)):
            out[key] = [(x + spread * sign, y) for (x, y) in pose[key]]
    if st:
        # Plant the feet wider apart without moving the hips.
        for key, sign in (("fl", 1), ("bl", -1)):
            pts = pose[key]
            out[key] = [pts[0], (pts[1][0] + st * sign, pts[1][1]), (pts[2][0] + st * sign, pts[2][1])]
    if hu:
        # Head forward and down, shoulders up: weight carried in front.
        out["head"] = (pose["head"][0] + hu, pose["head"][1] + hu)
        out["neck"] = (pose["neck"][0], pose["neck"][1] + max(0, hu - 1))
    return out


def render_pose(pose, sp, size=FRAME):
    pose = shape_pose(pose, sp)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    lw = sp["limb_w"]
    skin = sp["skin"]
    arm_cols = (sp["shirt"] if sp["sleeves"] and sp["shirt_style"] not in ("vest",) else skin, skin)
    if sp["shirt_style"] == "gi":
        arm_cols = (sp["shirt"], sp["shirt"])
    leg_cols = (sp["pants"], sp["pants"])
    # Each part draws its own outline immediately before its own fill.
    #
    # This used to be two passes: every outline, then every fill. That meant a part drawn
    # later covered the outline of the parts before it, so the front arm lost its rim
    # exactly where it crossed the torso and the two read as one shapeless mass. Drawing
    # them together gives every part a clean edge against whatever is behind it.
    for part in pose["order"]:
        for outline_pass in (True, False):
            if part == "torso":
                draw_torso(d, pose, sp, outline_pass)
            elif part == "head":
                draw_head(d, pose, sp, outline_pass)
            elif part in ("fa", "ba"):
                draw_limb(d, pose[part], lw, arm_cols, outline_pass)
                draw_hand(d, pose[part][2], sp, outline_pass, lw)
            elif part in ("fl", "bl"):
                draw_limb(d, pose[part], lw, leg_cols, outline_pass)
                draw_shoe(d, pose[part][2], sp, outline_pass, lw)
    if sp.get("scale", 1.0) != 1.0:
        s = sp["scale"]
        w = int(size * s)
        scaled = img.resize((w, w), Image.NEAREST)
        out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        # keep feet on the ground line (y=58)
        out.paste(scaled, ((size - w) // 2, 58 - int(58 * s)), scaled)
        return out
    return img

def render_portrait(sp):
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pose = P()
    # background swatch
    rect(d, [0, 0, 31, 31], fill=(40, 30, 50, 255))
    rect(d, [1, 1, 30, 30], fill=(70, 50, 90, 255))
    # shoulders
    sh = rgba(sp["shirt"])
    rect(d, [4, 24, 27, 31], fill=OUTLINE)
    rect(d, [5, 25, 26, 31], fill=sh)
    for op in (True, False):
        draw_head(d, pose, sp, op, r=10, center=(16, 15), portrait=True)
    return img

# ---------------------------------------------------------------------------
# Sheet packing + Godot SpriteFrames
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Builds
#
# A player should be able to tell what is about to hit them from the outline alone,
# before any colour or animation registers. Everyone used to share one body, so a heavy
# and a rusher had the same silhouette and only the palette told them apart.
#
# The build comes from the enemy's archetype in gen_data rather than a second list kept
# here, which would drift the moment an archetype changed. Anything a character sets by
# hand still wins.
# ---------------------------------------------------------------------------
BUILDS = {
    # narrow, light, small head: reads as fast
    D.AR_RUSHER:   dict(torso_w=10, limb_w=3, head_r=6, scale=0.94, stance=0, hunch=0),
    D.AR_GRUNT:    dict(torso_w=12, limb_w=4, head_r=7, scale=1.00, stance=0, hunch=0),
    # a wide stance and a slight hunch: someone carrying something heavy
    D.AR_WEAPON:   dict(torso_w=13, limb_w=4, head_r=7, scale=1.00, stance=1, hunch=1),
    D.AR_RANGED:   dict(torso_w=11, limb_w=3, head_r=7, scale=0.97, stance=0, hunch=0),
    # broad and planted
    D.AR_GRAPPLER: dict(torso_w=15, limb_w=5, head_r=7, scale=1.05, stance=2, hunch=1),
    # widest, heaviest, and the head is small against the body, which is what sells mass
    D.AR_HEAVY:    dict(torso_w=17, limb_w=6, head_r=7, scale=1.10, stance=3, hunch=2),
    D.AR_BOSS:     dict(torso_w=18, limb_w=6, head_r=8, scale=1.14, stance=3, hunch=2),
}


def _character_archetypes():
    """character id -> archetype, read straight off the enemy definitions."""
    out = {}
    for e in D.ENEMIES:
        m = re.search(r"characters/([a-z0-9_]+)_frames\.tres", e["sprite_frames"].path)
        if m:
            out[m.group(1)] = e["archetype"]
    return out


def apply_builds():
    arch = _character_archetypes()
    missing = [c for c in arch if c not in CHARACTERS]
    if missing:
        raise SystemExit("enemies reference characters that do not exist: %s" % ", ".join(sorted(missing)))
    applied = 0
    for cid, a in arch.items():
        sp = CHARACTERS[cid]
        for k, v in BUILDS[a].items():
            if k not in sp["_explicit"]:
                sp[k] = v
        applied += 1
    return applied


def build_character(cid, sp):
    anim_names = sp["anims"]
    frames = []  # (anim, index, image)
    for an in anim_names:
        poses, fps, loop = ANIMS[an]
        for i, pose in enumerate(poses):
            frames.append((an, i, render_pose(pose, sp)))
    n = len(frames)
    rows = (n + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * FRAME, rows * FRAME), (0, 0, 0, 0))
    regions = {}
    for idx, (an, i, im) in enumerate(frames):
        x = (idx % COLS) * FRAME
        y = (idx // COLS) * FRAME
        sheet.paste(im, (x, y), im)
        regions.setdefault(an, []).append((x, y))
    os.makedirs(OUT_CHARS, exist_ok=True)
    png_path = os.path.join(OUT_CHARS, f"{cid}.png")
    sheet.save(png_path)
    write_spriteframes(cid, regions, anim_names)
    os.makedirs(OUT_PORTRAITS, exist_ok=True)
    render_portrait(sp).save(os.path.join(OUT_PORTRAITS, f"{cid}.png"))
    return n

def write_spriteframes(cid, regions, anim_names):
    lines = []
    sub_count = sum(len(v) for v in regions.values())
    lines.append(f'[gd_resource type="SpriteFrames" load_steps={sub_count + 2} format=3]')
    lines.append("")
    lines.append(f'[ext_resource type="Texture2D" path="res://assets/art/characters/{cid}.png" id="1"]')
    lines.append("")
    sub_ids = {}
    k = 0
    for an in anim_names:
        for i, (x, y) in enumerate(regions[an]):
            k += 1
            sid = f"Atlas_{k}"
            sub_ids[(an, i)] = sid
            lines.append(f'[sub_resource type="AtlasTexture" id="{sid}"]')
            lines.append('atlas = ExtResource("1")')
            lines.append(f"region = Rect2({x}, {y}, {FRAME}, {FRAME})")
            lines.append("")
    lines.append("[resource]")
    entries = []
    for an in anim_names:
        poses, fps, loop = ANIMS[an]
        fr = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % sub_ids[(an, i)] for i in range(len(regions[an])))
        entries.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % (fr, "true" if loop else "false", an, float(fps)))
    lines.append("animations = [" + ", ".join(entries) + "]")
    lines.append("")
    with open(os.path.join(OUT_CHARS, f"{cid}_frames.tres"), "w", newline="\n") as f:
        f.write("\n".join(lines))

def main():
    n = apply_builds()
    print("builds applied to %d enemy characters" % n)
    total = 0
    for cid, sp in CHARACTERS.items():
        n = build_character(cid, sp)
        total += n
        print(f"  {cid}: {n} frames")
    print(f"Generated {len(CHARACTERS)} characters, {total} frames -> {OUT_CHARS}")

if __name__ == "__main__":
    main()

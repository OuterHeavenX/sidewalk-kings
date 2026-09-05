#!/usr/bin/env python3
"""
Sidewalk Kings - cutscenes.

A cutscene is a list of steps: camera moves, actor blocking, dialogue, and the flags they
set. Same shape as an area layout and for the same reason. It is a sequence of
instructions rather than a set of properties, and it changes far more often than the code
that runs it, so it lives in data.

Run from the project root:  python tools/gen_cutscenes.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "cutscenes")


def wait(t):            return {"do": "wait", "time": t}
def say(d):             return {"do": "say", "dialogue": d}
def camera(x, y=-12.0, t=1.2):  return {"do": "camera", "x": x, "y": y, "time": t}
def camera_follow():    return {"do": "camera", "follow": True}
def move(actor, x, t=1.0):      return {"do": "move", "actor": actor, "x": x, "time": t}
def face(actor, d):     return {"do": "face", "actor": actor, "dir": d}
def anim(actor, name):  return {"do": "anim", "actor": actor, "name": name}
def flag(name, value=True):     return {"do": "flag", "name": name, "value": value}
def quest(**kw):        return dict({"do": "quest"}, **kw)
def shake(a=2.0):       return {"do": "shake", "amount": a}
def sfx(i):             return {"do": "sfx", "id": i}
def music(i):           return {"do": "music", "id": i}


CUTSCENES = {
    # The arrival. Kip expects the end of a trail and finds a man at a desk, so the scene
    # is built to deflate: the camera pans past the filing cabinets before it finds him,
    # and he speaks first, about the wrong thing.
    "line_office_arrival": [
        flag("seen_line_office"),
        music("shop"),
        camera(200.0, -12.0, 0.1),
        wait(0.6),
        camera(560.0, -12.0, 2.4),
        move("player", 300.0, 1.6),
        wait(0.4),
        say("manager_meet"),
        face("player", 1),
        move("player", 400.0, 0.9),
        wait(0.3),
        say("manager_reveal"),
        wait(0.4),
        say("manager_end"),
        # Explicit, even though manager_end's last line also sets it. A flag that only
        # exists inside dialogue is lost the moment somebody skips the scene, and the
        # chapter then cannot be finished. Story-critical state belongs on a step.
        flag("chapter_2_done"),
        camera_follow(),
        wait(0.3),
    ],
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for cid, steps in CUTSCENES.items():
        path = os.path.join(OUT, cid + ".json")
        with open(path, "w", newline="\n") as f:
            json.dump({"id": cid, "steps": steps}, f, indent=1)
        print("  %-24s %d steps" % (cid, len(steps)))
    print("cutscenes: %d" % len(CUTSCENES))


if __name__ == "__main__":
    main()

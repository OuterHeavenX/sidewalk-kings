#!/usr/bin/env python3
"""
Sidewalk Kings - build stamp.

Writes `data/build.json` with the commit the build came from and the date it was made.

The version number alone cannot answer the question people actually ask, which is "am I
running the update or the old one?". Every deploy so far has reported v0.1.1, because the
version only changes when someone remembers to change it, and a service worker will happily
serve a cached build that reports exactly the same string as the new one. The commit does
change, every time, without anyone remembering anything.

Run from the project root:  python tools/stamp_build.py
"""
import datetime
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# JSON, not the .txt this first shipped as: the export preset excludes "*.txt" and
# includes "*.json", so the stamp was written and then silently dropped from the
# package. The game reported "dev" in an exported build and nothing said why.
OUT = os.path.join(ROOT, "data", "build.json")


def git(*args):
    try:
        out = subprocess.run(["git"] + list(args), cwd=ROOT,
                             capture_output=True, text=True, timeout=20)
        return out.stdout.strip() if out.returncode == 0 else ""
    except Exception:
        return ""


def main():
    sha = git("rev-parse", "--short=7", "HEAD")
    if not sha:
        # No git here: a source drop, or an export from an unpacked archive. Say so rather
        # than writing something that looks like a real commit.
        sha = "nogit"
    elif git("status", "--porcelain"):
        # A build made from a dirty tree is not the commit it claims to be, and quietly
        # pretending otherwise is how you chase a bug that only exists on someone's desk.
        sha += "+"
    date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", newline="\n") as f:
        json.dump({"commit": sha, "date": date}, f, indent=1)
    print("build stamp: %s %s" % (sha, date))
    return 0


if __name__ == "__main__":
    sys.exit(main())

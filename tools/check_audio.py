#!/usr/bin/env python3
"""
Sidewalk Kings - audio loudness checks.

A landed hit has to sound harder than the swing that led into it. That is not a matter of
taste, it is measurable, and the first version of these sounds failed it badly while
looking perfectly reasonable in the generator: every impact normalised to a loud PEAK and
had almost no energy behind it, so a punch connecting was a tick and the whoosh before it
was the loudest part of the hit. Playtesting reported it as "no punch when it lands".

Peak level is the wrong measure. A click and a thump can share a peak and differ by ten
decibels of actual energy, so everything here is RMS.

This lives beside the generator rather than in the Godot smoke test because Godot imports
WAVs as QOA: AudioStreamWAV.data is compressed bytes at runtime, and decoding it as PCM
produces noise that measures about -5 dB for every sound, which is exactly the kind of
instrument that reports success while measuring nothing. The uncompressed source files are
here, so the check is here.

Run from the project root:  python tools/check_audio.py
"""
import math
import os
import struct
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX = os.path.join(ROOT, "assets", "audio", "sfx")

# Each impact and the swing it follows. An attack plays its swing on start-up and its
# impact on contact, so these two land back to back and the second must be the louder.
IMPACT_OVER_SWING = [
    ("hit_light", "whoosh_light"),
    ("hit_heavy", "whoosh_heavy"),
    ("hit_kick", "kick"),
    ("hit_weapon", "whoosh_heavy"),
]

# A crit is the hardest the game hits. Built by mixing bright tones over a heavy and
# normalising to peak, it came out quieter than a plain heavy: the added highs raised the
# peak, so normalise scaled the whole thing down.
LOUDER_THAN = [("hit_crit", "hit_heavy")]

# Below this an impact is a tick rather than a hit, whatever it is being compared against.
MIN_IMPACT_RMS_DB = -18.0


def rms_db(name):
    path = os.path.join(SFX, name + ".wav")
    if not os.path.exists(path):
        return None
    w = wave.open(path, "rb")
    n, sw = w.getnframes(), w.getsampwidth()
    data = w.readframes(n)
    w.close()
    if sw != 2 or n == 0:
        return None
    s = struct.unpack("<%dh" % (len(data) // 2), data)
    acc = 0.0
    for v in s:
        x = v / 32768.0
        acc += x * x
    return 20.0 * math.log10(math.sqrt(acc / len(s)) + 1e-9)


def main():
    failures = []
    measured = {}

    def get(name):
        if name not in measured:
            measured[name] = rms_db(name)
        return measured[name]

    for impact, swing in IMPACT_OVER_SWING:
        a, b = get(impact), get(swing)
        if a is None or b is None:
            failures.append("missing sound: %s or %s" % (impact, swing))
            continue
        if a <= b:
            failures.append(
                "%s (%.1f dB) is not louder than the swing %s (%.1f dB)"
                % (impact, a, swing, b))

    for louder, quieter in LOUDER_THAN:
        a, b = get(louder), get(quieter)
        if a is None or b is None:
            failures.append("missing sound: %s or %s" % (louder, quieter))
        elif a <= b:
            failures.append("%s (%.1f dB) should land harder than %s (%.1f dB)"
                            % (louder, a, quieter, b))

    for impact, _ in IMPACT_OVER_SWING:
        a = get(impact)
        if a is not None and a < MIN_IMPACT_RMS_DB:
            failures.append("%s is too thin to read as an impact (%.1f dB, floor %.1f)"
                            % (impact, a, MIN_IMPACT_RMS_DB))

    for name in sorted(measured):
        if measured[name] is None:
            print("  %-14s MISSING" % name)
        else:
            print("  %-14s %6.1f dB RMS" % (name, measured[name]))

    if failures:
        print("\naudio check FAILED:")
        for f in failures:
            print("  - " + f)
        return 1
    print("\naudio OK: every impact outweighs its swing")
    return 0


if __name__ == "__main__":
    sys.exit(main())

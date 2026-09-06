#!/usr/bin/env python3
"""
Sidewalk Kings - original procedural audio generator.

Writes 16-bit mono WAV files for every sound effect and music loop the game needs.
All material is synthesised here from scratch, so it is original to this project and
freely distributable with the repository.

Run from the project root:  python tools/gen_audio.py
"""
import os, math, random, struct, wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUS_DIR = os.path.join(ROOT, "assets", "audio", "music")
AMB_DIR = os.path.join(ROOT, "assets", "audio", "ambience")
SR = 22050

for d in (SFX_DIR, MUS_DIR, AMB_DIR):
    os.makedirs(d, exist_ok=True)

# ----------------------------------------------------------------------
# Core helpers
# ----------------------------------------------------------------------
def write_wav(path, samples, sr=SR, loop=False):
    frames = bytearray()
    for s in samples:
        v = int(max(-1.0, min(1.0, s)) * 32000)
        frames += struct.pack("<h", v)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(bytes(frames))
    if loop:
        _append_loop_chunk(path, len(samples), sr)


def _append_loop_chunk(path, num_frames, sr):
    """Add a WAV 'smpl' chunk marking the whole file as a loop.

    Godot's WAV importer defaults to "Detect From WAV", which means it looks for exactly
    this chunk. Without it a track imports with looping disabled, plays once, and then the
    game is silent for the rest of the session.
    """
    with open(path, "rb") as f:
        data = bytearray(f.read())
    # manufacturer, product, sample period (ns), MIDI note, pitch fraction,
    # SMPTE format, SMPTE offset, loop count, sampler data bytes
    body = struct.pack("<9I", 0, 0, int(1_000_000_000 / sr), 60, 0, 0, 0, 1, 0)
    # loop: id, type (0 = forward), start, end, fraction, play count (0 = forever)
    body += struct.pack("<6I", 0, 0, 0, max(0, num_frames - 1), 0, 0)
    data += b"smpl" + struct.pack("<I", len(body)) + body
    struct.pack_into("<I", data, 4, len(data) - 8)      # fix the RIFF size
    with open(path, "wb") as f:
        f.write(data)

def env_ad(n, attack=0.005, decay=0.2, sustain=0.0, release=0.05, sr=SR):
    a = int(attack * sr); d = int(decay * sr); r = int(release * sr)
    out = []
    for i in range(n):
        if i < a and a > 0:
            out.append(i / a)
        elif i < a + d and d > 0:
            t = (i - a) / d
            out.append(1.0 + (sustain - 1.0) * t)
        elif i < n - r:
            out.append(sustain)
        else:
            t = (n - i) / max(1, r)
            out.append(sustain * t)
    return out

def exp_env(n, decay=8.0):
    return [math.exp(-decay * i / n) for i in range(n)]

def osc(kind, phase):
    if kind == "sine":
        return math.sin(phase)
    if kind == "square":
        return 1.0 if (phase % math.tau) < math.pi else -1.0
    if kind == "pulse25":
        return 1.0 if (phase % math.tau) < math.pi * 0.5 else -1.0
    if kind == "saw":
        return ((phase % math.tau) / math.pi) - 1.0
    if kind == "tri":
        p = (phase % math.tau) / math.tau
        return 4 * abs(p - 0.5) - 1.0
    return 0.0

def tone(freq, dur, kind="square", vol=0.5, decay=6.0, sr=SR, detune=0.0, vib=0.0, vibf=6.0, slide=0.0):
    n = int(dur * sr)
    out = [0.0] * n
    ph = 0.0; ph2 = 0.0
    for i in range(n):
        t = i / sr
        f = freq * (1.0 + slide * t)
        if vib:
            f *= 1.0 + vib * math.sin(math.tau * vibf * t)
        ph += math.tau * f / sr
        v = osc(kind, ph)
        if detune:
            ph2 += math.tau * f * (1 + detune) / sr
            v = (v + osc(kind, ph2)) * 0.5
        out[i] = v * vol * math.exp(-decay * i / n)
    return out

def noise_burst(dur, vol=0.5, decay=10.0, lp=0.0, seed=1, sr=SR):
    rnd = random.Random(seed)
    n = int(dur * sr)
    out = [0.0] * n
    prev = 0.0
    for i in range(n):
        v = rnd.uniform(-1, 1)
        if lp:
            v = prev + (v - prev) * lp
            prev = v
        out[i] = v * vol * math.exp(-decay * i / n)
    return out

def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out

def cat(*tracks):
    out = []
    for t in tracks:
        out.extend(t)
    return out

def silence(dur, sr=SR):
    return [0.0] * int(dur * sr)

def overlay(base, add, at, sr=SR):
    i0 = int(at * sr)
    need = i0 + len(add)
    if need > len(base):
        base.extend([0.0] * (need - len(base)))
    for i, v in enumerate(add):
        base[i0 + i] += v
    return base

def soft_clip(track, drive=1.0):
    return [math.tanh(v * drive) for v in track]

def normalize(track, peak=0.86):
    m = max((abs(v) for v in track), default=0.0)
    if m < 1e-6:
        return track
    k = peak / m
    return [v * k for v in track]

def lowpass(track, a=0.3):
    out = []
    prev = 0.0
    for v in track:
        prev = prev + (v - prev) * a
        out.append(prev)
    return out

# ----------------------------------------------------------------------
# Sound effects
# ----------------------------------------------------------------------
def sfx_punch_light():
    return normalize(mix(
        noise_burst(0.09, 0.7, 26, lp=0.42, seed=2),
        tone(190, 0.09, "sine", 0.6, 30, slide=-0.55),
    ), 0.8)

def sfx_punch_heavy():
    return normalize(mix(
        noise_burst(0.2, 0.85, 13, lp=0.24, seed=3),
        tone(105, 0.22, "sine", 0.9, 12, slide=-0.5),
        tone(64, 0.24, "sine", 0.6, 9, slide=-0.35),
    ), 0.92)

def sfx_kick():
    return normalize(mix(
        noise_burst(0.13, 0.6, 20, lp=0.3, seed=5),
        tone(140, 0.14, "tri", 0.7, 18, slide=-0.6),
    ), 0.85)

def sfx_whoosh(pitch=1.0, dur=0.16):
    n = int(dur * SR)
    rnd = random.Random(11)
    out = []
    prev = 0.0
    for i in range(n):
        t = i / n
        a = 0.06 + 0.5 * math.sin(math.pi * t)          # band sweep
        v = rnd.uniform(-1, 1)
        prev = prev + (v - prev) * (a * pitch)
        out.append(prev * math.sin(math.pi * t) * 0.75)
    return normalize(out, 0.55)

# A punch landing is three sounds at once: the slap of contact, the meat behind it, and a
# low thump you feel more than hear. The first version of these had only the slap. Its
# deepest component was a 300 Hz sine dying in 40 ms, which measured -25 dB RMS against a
# -16.7 dB whoosh -- so the wind-up was audibly louder than the impact it was leading to,
# and a landed hit read as a tick. Peak level hid it: these normalised to -1.6 dB peak and
# sounded like nothing, because a spike has a high peak and almost no energy.
#
# Judge these by RMS, not peak. An impact should sit at or above the swing that precedes
# it. soft_clip before normalize is what buys that: it packs the transient down and lets
# the low end come up, which also keeps the hit audible on a phone speaker that cannot
# reproduce the bottom octave at all.

def sfx_hit_light():
    return normalize(soft_clip(mix(
        noise_burst(0.055, 0.70, 22, lp=0.50, seed=7),      # contact
        tone(260, 0.10, "square", 0.30, 14, slide=-0.55),   # meat
        tone(140, 0.15, "sine", 0.70, 8, slide=-0.30),      # body
        tone(95, 0.17, "sine", 0.60, 6),                    # thump
    ), 1.35), 0.90)

def sfx_hit_heavy():
    return normalize(soft_clip(mix(
        noise_burst(0.10, 0.75, 14, lp=0.36, seed=8),
        tone(300, 0.12, "square", 0.30, 12, slide=-0.6),
        tone(120, 0.26, "sine", 0.95, 6, slide=-0.35),
        tone(68, 0.32, "sine", 0.75, 4.5),
    ), 1.5), 0.95)

def sfx_hit_kick():
    """A kick landing, distinct from a punch: duller, lower, and longer.

    A shin carries more mass and less snap than a fist, so the bright contact layer is
    quieter and more filtered while the low end runs on. Without this every kick in the
    game landed with the exact sound of a haymaker, which is why a combo read as one
    repeated noise rather than as different limbs.
    """
    return normalize(soft_clip(mix(
        noise_burst(0.09, 0.50, 18, lp=0.26, seed=17),
        tone(190, 0.13, "square", 0.26, 13, slide=-0.5),
        tone(105, 0.24, "sine", 0.90, 6, slide=-0.28),
        tone(58, 0.30, "sine", 0.80, 4.0),
    ), 1.45), 0.94)

def sfx_hit_weapon():
    """A bat or pipe connecting: a bright crack over the same body every impact needs.

    This had the original defect too and it showed up only once the fists were fixed --
    a weapon hit measured -23 dB RMS, quieter than a bare jab, which is exactly backwards
    for the thing you spent money on.
    """
    return normalize(soft_clip(mix(
        noise_burst(0.075, 0.65, 20, lp=0.72, seed=9),
        tone(1180, 0.10, "square", 0.26, 20, slide=-0.35),
        tone(1570, 0.07, "sine", 0.18, 24, slide=-0.3),
        tone(320, 0.14, "square", 0.30, 12, slide=-0.5),
        tone(130, 0.22, "sine", 0.80, 7, slide=-0.3),
        tone(74, 0.26, "sine", 0.55, 5),
    ), 1.45), 0.95)

def sfx_hit_crit():
    """The biggest hit in the game, and it has to measure that way.

    Building this by mixing bright tones on top of sfx_hit_heavy and normalising to peak
    made it quieter than a plain heavy: the added highs raised the peak, so normalize
    scaled the whole thing down. Peak level says nothing about how hard something lands.
    """
    return normalize(soft_clip(mix(
        sfx_hit_heavy(),
        tone(880, 0.16, "pulse25", 0.24, 14, slide=0.35),
        tone(1320, 0.12, "square", 0.16, 18, slide=0.5),
        tone(52, 0.36, "sine", 0.70, 3.5),
    ), 1.9), 0.97)

def sfx_block():
    return normalize(mix(
        noise_burst(0.1, 0.5, 26, lp=0.5, seed=21),
        tone(300, 0.12, "square", 0.35, 22, slide=0.2),
    ), 0.7)

def sfx_throw():
    base = sfx_whoosh(1.6, 0.22)
    return normalize(mix(base, tone(220, 0.2, "tri", 0.35, 10, slide=0.6)), 0.8)

def sfx_land():
    return normalize(mix(
        noise_burst(0.12, 0.55, 24, lp=0.22, seed=13),
        tone(88, 0.14, "sine", 0.6, 20, slide=-0.4),
    ), 0.7)

def sfx_jump():
    return normalize(tone(300, 0.16, "square", 0.4, 12, slide=1.4), 0.55)

def sfx_step():
    # Fixed seed. This drew from the unseeded global RNG, so every run of the generator
    # produced a different footstep and a spurious diff in the repository -- which quietly
    # breaks the one guarantee the pipeline offers, that regenerating from source gives you
    # back the same assets. The variety is added at playback anyway: Player passes a pitch
    # spread to play_sfx, so no two steps sound alike regardless of what is on disk.
    return normalize(noise_burst(0.05, 0.32, 40, lp=0.22, seed=41), 0.35)

def sfx_hurt(pitch=1.0):
    return normalize(mix(
        tone(340 * pitch, 0.18, "saw", 0.4, 12, slide=-0.5, vib=0.03),
        noise_burst(0.1, 0.3, 24, lp=0.55, seed=17),
    ), 0.75)

def sfx_enemy_hurt():
    return sfx_hurt(0.8)

def sfx_enemy_defeat():
    return normalize(cat(
        mix(tone(300, 0.2, "saw", 0.4, 8, slide=-0.55), noise_burst(0.14, 0.3, 16, lp=0.4, seed=19)),
        tone(170, 0.22, "tri", 0.3, 9, slide=-0.5),
    ), 0.8)

def sfx_knockdown():
    return normalize(mix(
        noise_burst(0.26, 0.7, 10, lp=0.18, seed=23),
        tone(72, 0.3, "sine", 0.7, 8, slide=-0.3),
    ), 0.82)

def sfx_money():
    return normalize(cat(
        tone(1180, 0.045, "square", 0.32, 22),
        tone(1560, 0.05, "square", 0.3, 20),
        tone(2100, 0.08, "square", 0.26, 16),
    ), 0.62)

def sfx_pickup():
    return normalize(cat(
        tone(660, 0.05, "pulse25", 0.3, 18),
        tone(990, 0.09, "pulse25", 0.28, 14),
    ), 0.6)

def sfx_purchase():
    return normalize(cat(
        tone(520, 0.06, "square", 0.3, 16),
        tone(780, 0.06, "square", 0.3, 16),
        tone(1040, 0.14, "square", 0.28, 10),
    ), 0.65)

def sfx_eat():
    return normalize(cat(
        mix(noise_burst(0.07, 0.4, 26, lp=0.3, seed=31), tone(180, 0.07, "tri", 0.3, 22)),
        silence(0.03),
        mix(noise_burst(0.07, 0.35, 26, lp=0.3, seed=32), tone(150, 0.07, "tri", 0.28, 22)),
    ), 0.6)

def sfx_menu_move():
    return normalize(tone(760, 0.045, "square", 0.25, 22), 0.45)

def sfx_menu_confirm():
    return normalize(cat(tone(700, 0.05, "square", 0.28, 18), tone(1050, 0.1, "square", 0.26, 12)), 0.55)

def sfx_menu_back():
    return normalize(cat(tone(600, 0.05, "square", 0.26, 18), tone(400, 0.1, "square", 0.24, 12)), 0.5)

def sfx_menu_deny():
    return normalize(cat(tone(300, 0.07, "saw", 0.3, 14), tone(200, 0.12, "saw", 0.28, 12)), 0.55)

def sfx_level_up():
    notes = [523, 659, 784, 1046]
    return normalize(cat(*[tone(f, 0.11, "pulse25", 0.3, 7) for f in notes]), 0.7)

def sfx_quest_start():
    return normalize(cat(tone(587, 0.08, "square", 0.28, 12), tone(880, 0.14, "square", 0.26, 8)), 0.6)

def sfx_quest_complete():
    return normalize(cat(
        tone(659, 0.09, "pulse25", 0.3, 10), tone(784, 0.09, "pulse25", 0.3, 10),
        tone(1046, 0.22, "pulse25", 0.3, 6),
    ), 0.7)

def sfx_unlock():
    return normalize(cat(
        tone(440, 0.07, "square", 0.26, 12), tone(660, 0.07, "square", 0.26, 12),
        tone(880, 0.08, "square", 0.26, 12), tone(1320, 0.2, "pulse25", 0.28, 6),
    ), 0.7)

def sfx_weapon_pickup():
    return normalize(cat(tone(400, 0.05, "square", 0.28, 18), tone(600, 0.09, "square", 0.26, 14)), 0.55)

def sfx_weapon_break():
    return normalize(mix(
        noise_burst(0.3, 0.8, 9, lp=0.8, seed=41),
        tone(1400, 0.16, "square", 0.24, 16, slide=-0.6),
        tone(2100, 0.1, "square", 0.18, 22, slide=-0.5),
    ), 0.8)

def sfx_break_object():
    return normalize(mix(
        noise_burst(0.34, 0.85, 8, lp=0.5, seed=43),
        tone(240, 0.2, "saw", 0.4, 12, slide=-0.4),
    ), 0.85)

def sfx_door():
    return normalize(mix(
        noise_burst(0.3, 0.4, 7, lp=0.16, seed=47),
        tone(150, 0.3, "tri", 0.3, 7, slide=0.25),
    ), 0.6)

def sfx_boss_warning():
    out = []
    for i in range(3):
        out = cat(out, tone(160, 0.22, "saw", 0.45, 3, vib=0.02, vibf=9), silence(0.08))
    return normalize(out, 0.8)

def sfx_telegraph():
    """Short rising warning under an enemy wind-up. Deliberately quiet and unmusical."""
    return normalize(cat(
        tone(320, 0.07, "square", 0.28, 14),
        tone(430, 0.10, "square", 0.26, 11),
    ), 0.5)

def sfx_special_charge():
    return normalize(mix(
        tone(180, 0.5, "saw", 0.35, 0.6, slide=2.2, vib=0.02, vibf=14),
        noise_burst(0.5, 0.2, 1.5, lp=0.1, seed=53),
    ), 0.7)

def sfx_special_hit():
    return normalize(mix(
        noise_burst(0.4, 0.9, 6, lp=0.3, seed=59),
        tone(90, 0.45, "sine", 0.9, 5, slide=-0.3),
        tone(500, 0.2, "square", 0.3, 12, slide=-0.6),
        tone(1300, 0.14, "pulse25", 0.2, 16, slide=-0.4),
    ), 0.98)

def sfx_dash():
    return normalize(sfx_whoosh(2.2, 0.14), 0.5)

def sfx_grab():
    return normalize(mix(
        noise_burst(0.08, 0.4, 26, lp=0.35, seed=61),
        tone(240, 0.1, "tri", 0.35, 18, slide=0.3),
    ), 0.6)

def sfx_notify():
    return normalize(cat(tone(880, 0.05, "pulse25", 0.24, 18), tone(1170, 0.1, "pulse25", 0.22, 12)), 0.5)

def sfx_save():
    return normalize(cat(tone(660, 0.07, "sine", 0.3, 10), tone(990, 0.07, "sine", 0.3, 10), tone(1320, 0.16, "sine", 0.28, 6)), 0.6)

def sfx_pause():
    return normalize(cat(tone(500, 0.04, "square", 0.24, 20), tone(340, 0.1, "square", 0.22, 14)), 0.5)

SFX = {
    "punch_light": sfx_punch_light, "punch_heavy": sfx_punch_heavy, "kick": sfx_kick,
    "whoosh_light": lambda: sfx_whoosh(1.0, 0.13), "whoosh_heavy": lambda: sfx_whoosh(0.7, 0.2),
    "hit_light": sfx_hit_light, "hit_heavy": sfx_hit_heavy, "hit_weapon": sfx_hit_weapon, "hit_crit": sfx_hit_crit,
    "hit_kick": sfx_hit_kick,
    "block": sfx_block, "throw": sfx_throw, "land": sfx_land, "jump": sfx_jump, "step": sfx_step,
    "hurt": sfx_hurt, "enemy_hurt": sfx_enemy_hurt, "enemy_defeat": sfx_enemy_defeat, "knockdown": sfx_knockdown,
    "money": sfx_money, "pickup": sfx_pickup, "purchase": sfx_purchase, "eat": sfx_eat,
    "menu_move": sfx_menu_move, "menu_confirm": sfx_menu_confirm, "menu_back": sfx_menu_back, "menu_deny": sfx_menu_deny,
    "level_up": sfx_level_up, "quest_start": sfx_quest_start, "quest_complete": sfx_quest_complete, "unlock": sfx_unlock,
    "weapon_pickup": sfx_weapon_pickup, "weapon_break": sfx_weapon_break, "break_object": sfx_break_object,
    "door": sfx_door, "boss_warning": sfx_boss_warning, "telegraph": sfx_telegraph, "special_charge": sfx_special_charge,
    "special_hit": sfx_special_hit, "dash": sfx_dash, "grab": sfx_grab, "notify": sfx_notify,
    "save": sfx_save, "pause": sfx_pause,
}

# ----------------------------------------------------------------------
# Music
# ----------------------------------------------------------------------
NOTES = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}

def nf(name):
    """note name like 'A3' -> frequency"""
    if name in ("-", "", None):
        return 0.0
    i = 1
    if len(name) > 1 and name[1] == "#":
        i = 2
    p = NOTES[name[:i]]
    octv = int(name[i:])
    midi = (octv + 1) * 12 + p
    return 440.0 * (2 ** ((midi - 69) / 12.0))

def seq_track(pattern, step_dur, kind="square", vol=0.3, decay=5.0, detune=0.0, vib=0.0, gate=0.9):
    """pattern: list of note names or '-' for rest, '.' to hold."""
    out = []
    i = 0
    while i < len(pattern):
        note = pattern[i]
        length = 1
        while i + length < len(pattern) and pattern[i + length] == ".":
            length += 1
        dur = step_dur * length
        if note in ("-", "."):
            out.extend(silence(dur))
        else:
            body = tone(nf(note), dur * gate, kind, vol, decay, detune=detune, vib=vib)
            out.extend(body)
            out.extend(silence(dur - dur * gate))
        i += length
    return out

def drum_kick(dur=0.14):
    return mix(tone(120, dur, "sine", 0.85, 22, slide=-0.72), noise_burst(0.03, 0.35, 40, lp=0.4, seed=71))

def drum_snare(dur=0.13):
    return mix(noise_burst(dur, 0.6, 22, lp=0.65, seed=73), tone(210, 0.06, "tri", 0.32, 28))

def drum_hat(dur=0.05, vol=0.28):
    return noise_burst(dur, vol, 60, lp=0.92, seed=79)

def drum_tom(f=180):
    return tone(f, 0.13, "sine", 0.55, 18, slide=-0.4)

def drum_track(pattern, step_dur, total_steps):
    """pattern: dict of 'k'/'s'/'h'/'t' -> list of step indices"""
    out = [0.0] * int(step_dur * total_steps * SR)
    for ch, steps in pattern.items():
        maker = {"k": drum_kick, "s": drum_snare, "h": drum_hat, "t": lambda: drum_tom(190)}[ch]
        for st in steps:
            overlay(out, maker(), st * step_dur)
    return out

def build_song(bpm, bars, bass, lead, harm, drums, lead_kind="pulse25", harm_kind="square",
               bass_kind="tri", lead_vol=0.26, harm_vol=0.16, bass_vol=0.34, swing=0.0):
    step = 60.0 / bpm / 4.0        # 16th notes
    steps_per_bar = 16
    total = bars * steps_per_bar
    tracks = []
    if bass:
        tracks.append(seq_track(bass * (bars // (len(bass) // steps_per_bar)), step, bass_kind, bass_vol, 3.0, gate=0.95))
    if lead:
        tracks.append(seq_track(lead * (bars // (len(lead) // steps_per_bar)), step, lead_kind, lead_vol, 4.0, detune=0.004, gate=0.85))
    if harm:
        tracks.append(seq_track(harm * (bars // (len(harm) // steps_per_bar)), step, harm_kind, harm_vol, 4.5, gate=0.8))
    if drums:
        dsteps = {}
        for ch, pat in drums.items():
            idx = []
            for b in range(bars):
                for s in pat:
                    idx.append(b * steps_per_bar + s)
            dsteps[ch] = idx
        tracks.append(drum_track(dsteps, step, total))
    song = mix(*tracks) if tracks else silence(1.0)
    song = soft_clip(song, 1.15)
    return normalize(song, 0.8)

def music_title():
    bass = ["A2", ".", ".", ".", "A2", ".", "-", "-", "F2", ".", ".", ".", "F2", ".", "-", "-",
            "C3", ".", ".", ".", "C3", ".", "-", "-", "G2", ".", ".", ".", "G2", ".", "E2", "."]
    lead = ["A4", ".", "C5", ".", "E5", ".", ".", ".", "D5", ".", "C5", ".", "A4", ".", ".", ".",
            "G4", ".", "A4", ".", "C5", ".", ".", ".", "B4", ".", "G4", ".", "-", "-", "-", "-"]
    harm = ["E4", ".", ".", ".", "-", "-", "-", "-", "A4", ".", ".", ".", "-", "-", "-", "-",
            "G4", ".", ".", ".", "-", "-", "-", "-", "D4", ".", ".", ".", "-", "-", "-", "-"]
    drums = {"k": [0, 6, 8, 14], "s": [4, 12], "h": [0, 2, 4, 6, 8, 10, 12, 14]}
    return build_song(118, 8, bass, lead, harm, drums)

def music_street():
    bass = ["D2", ".", "D2", ".", "-", "-", "A2", ".", "D2", ".", "-", "-", "C2", ".", "-", "-",
            "F2", ".", "F2", ".", "-", "-", "C3", ".", "G2", ".", "-", "-", "A2", ".", "-", "-"]
    lead = ["D4", ".", "F4", ".", "G4", ".", "A4", ".", "-", "-", "G4", ".", "F4", ".", "-", "-",
            "A4", ".", "C5", ".", "A4", ".", "G4", ".", "F4", ".", "D4", ".", "-", "-", "-", "-"]
    harm = ["A3", ".", "-", "-", "D4", ".", "-", "-", "F4", ".", "-", "-", "D4", ".", "-", "-",
            "C4", ".", "-", "-", "F4", ".", "-", "-", "G3", ".", "-", "-", "A3", ".", "-", "-"]
    drums = {"k": [0, 3, 7, 8, 11], "s": [4, 12],
             "h": [0, 2, 4, 6, 8, 10, 12, 14], "t": [15]}
    return build_song(138, 8, bass, lead, harm, drums, lead_vol=0.29)

def music_market():
    bass = ["G2", ".", "-", "G2", "-", "D3", "-", ".", "E2", ".", "-", "E2", "-", "B2", "-", ".",
            "C3", ".", "-", "C3", "-", "G3", "-", ".", "D3", ".", "-", "D3", "-", "A2", "-", "."]
    lead = ["B4", "-", "D5", "-", "G5", "-", "D5", "-", "B4", "-", "-", "-", "-", "-", "-", "-",
            "C5", "-", "E5", "-", "G5", "-", "E5", "-", "D5", "-", "B4", "-", "-", "-", "-", "-"]
    harm = ["G4", ".", ".", ".", "-", "-", "-", "-", "E4", ".", ".", ".", "-", "-", "-", "-",
            "C5", ".", ".", ".", "-", "-", "-", "-", "D5", ".", ".", ".", "-", "-", "-", "-"]
    drums = {"k": [0, 3, 8, 11], "s": [4, 12],
             "h": [0, 2, 3, 4, 6, 8, 10, 11, 12, 14, 15]}
    return build_song(146, 8, bass, lead, harm, drums, lead_kind="square", harm_kind="tri",
                      lead_vol=0.29)

def music_alley():
    bass = ["E2", ".", ".", ".", "-", "-", "E2", ".", "G2", ".", "-", "-", "A2", ".", "-", "-",
            "E2", ".", ".", ".", "-", "-", "E2", ".", "D2", ".", "-", "-", "C2", ".", "B1", "."]
    lead = ["E4", ".", "-", "G4", "-", "A4", ".", "-", "-", "-", "B4", ".", "A4", ".", "G4", ".",
            "E4", ".", "-", "D4", "-", "E4", ".", "-", "-", "-", "-", "-", "-", "-", "-", "-"]
    harm = ["B3", ".", ".", ".", ".", ".", ".", ".", "-", "-", "-", "-", "-", "-", "-", "-",
            "A3", ".", ".", ".", ".", ".", ".", ".", "-", "-", "-", "-", "-", "-", "-", "-"]
    drums = {"k": [0, 6, 10], "s": [4, 12], "h": [0, 2, 6, 8, 10, 14]}
    return build_song(130, 8, bass, lead, harm, drums, lead_kind="tri", harm_kind="saw",
                      lead_vol=0.27)

def music_industrial():
    bass = ["C2", "-", "C2", "-", "C2", "-", "D#2", "-", "C2", "-", "C2", "-", "G2", "-", "F2", "-",
            "A#1", "-", "A#1", "-", "A#1", "-", "C2", "-", "G1", "-", "G1", "-", "A#1", "-", "C2", "-"]
    lead = ["C4", "-", "D#4", "-", "G4", "-", "-", "-", "F4", "-", "D#4", "-", "C4", "-", "-", "-",
            "A#3", "-", "C4", "-", "D#4", "-", "-", "-", "G4", "-", "F4", "-", "D#4", "-", "-", "-"]
    harm = ["G3", ".", ".", ".", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-",
            "F3", ".", ".", ".", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-"]
    drums = {"k": [0, 3, 6, 8, 11], "s": [4, 12], "h": [0, 2, 4, 6, 8, 10, 12, 14], "t": [14]}
    return build_song(150, 8, bass, lead, harm, drums, lead_kind="saw", bass_kind="square",
                      lead_vol=0.26)

def music_boss():
    bass = ["D2", "-", "D2", "-", "D2", "-", "D2", "-", "F2", "-", "F2", "-", "E2", "-", "E2", "-",
            "D2", "-", "D2", "-", "D2", "-", "D2", "-", "A#1", "-", "C2", "-", "D2", "-", "-", "-"]
    lead = ["D5", "-", "-", "C5", "-", "A#4", "-", "-", "A4", "-", "-", "-", "-", "-", "-", "-",
            "F5", "-", "-", "E5", "-", "D5", "-", "-", "C5", "-", "A4", "-", "D5", "-", "-", "-"]
    harm = ["A4", "-", "-", "-", "F4", "-", "-", "-", "D4", "-", "-", "-", "-", "-", "-", "-",
            "A#4", "-", "-", "-", "A4", "-", "-", "-", "F4", "-", "-", "-", "-", "-", "-", "-"]
    drums = {"k": [0, 2, 6, 8, 10, 14], "s": [4, 12], "h": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], "t": [15]}
    return build_song(166, 8, bass, lead, harm, drums, lead_kind="saw", harm_kind="square",
                      lead_vol=0.28, bass_vol=0.40)

def music_tension():
    """A boss room before anything happens in it.

    Both boss areas used to play the boss theme on entry, so walking in blew the reveal and
    the fight starting changed nothing. This is what the room sounds like while it is still
    just a room: slow, sparse, and mostly space.
    """
    bass = ["D2", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-",
            "A#1", "-", "-", "-", "-", "-", "-", "-", "C2", "-", "-", "-", "-", "-", "-", "-"]
    lead = ["A4", "-", "-", "-", "-", "-", "-", "-", "-", "-", "F4", "-", "-", "-", "-", "-",
            "-", "-", "-", "-", "D4", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-"]
    harm = ["D4", ".", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-",
            "F4", ".", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-"]
    drums = {"k": [0], "h": [8]}
    return build_song(84, 8, bass, lead, harm, drums, lead_kind="tri", harm_kind="tri",
                      lead_vol=0.16, harm_vol=0.10, bass_vol=0.26)


def music_battle():
    """What a fight sounds like. The one track no area uses, so it always changes.

    Fast, straight-eight bass that never rests, a saw lead that keeps moving, and a kick
    pattern with a push on the "and" of two so it leans forward rather than sitting square.
    """
    bass = ["A1", "-", "A1", "-", "A1", "A1", "-", "A1", "A1", "-", "A1", "-", "C2", "-", "D2", "-",
            "A1", "-", "A1", "-", "A1", "A1", "-", "A1", "F1", "-", "G1", "-", "A1", "-", "-", "-"]
    lead = ["A4", "-", "C5", "-", "E5", "-", "D5", "C5", "A4", "-", "-", "C5", "-", "D5", "-", "-",
            "E5", "-", "G5", "-", "E5", "-", "D5", "C5", "D5", "-", "C5", "-", "A4", "-", "-", "-"]
    harm = ["E4", ".", "-", "-", "A4", ".", "-", "-", "E4", ".", "-", "-", "G4", ".", "-", "-",
            "A4", ".", "-", "-", "C5", ".", "-", "-", "G4", ".", "-", "-", "E4", ".", "-", "-"]
    drums = {"k": [0, 3, 6, 8, 11, 14], "s": [4, 12],
             "h": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], "t": [15]}
    return build_song(152, 8, bass, lead, harm, drums, lead_kind="saw", harm_kind="square",
                      bass_kind="square", lead_vol=0.26, bass_vol=0.38)


def music_victory():
    bass = ["C3", ".", "-", "-", "G2", ".", "-", "-", "A2", ".", "-", "-", "F2", ".", "-", "-"]
    lead = ["C5", ".", "E5", ".", "G5", ".", ".", ".", "-", "-", "E5", ".", "C5", ".", ".", "."]
    harm = ["G4", ".", ".", ".", "-", "-", "-", "-", "E4", ".", ".", ".", "-", "-", "-", "-"]
    drums = {"k": [0, 8], "s": [4, 12], "h": [0, 2, 4, 6, 8, 10, 12, 14]}
    return build_song(132, 2, bass, lead, harm, drums, lead_vol=0.30)

def music_shop():
    bass = ["F2", ".", "-", "-", "C3", ".", "-", "-", "A2", ".", "-", "-", "C3", ".", "-", "-",
            "A#2", ".", "-", "-", "F3", ".", "-", "-", "G2", ".", "-", "-", "C3", ".", "-", "-"]
    lead = ["A4", ".", "C5", ".", "-", "-", "F5", ".", "-", "-", "E5", ".", "C5", ".", "-", "-",
            "D5", ".", "F5", ".", "-", "-", "A5", ".", "-", "-", "G5", ".", "F5", ".", "-", "-"]
    harm = ["F4", ".", ".", ".", "-", "-", "-", "-", "A4", ".", ".", ".", "-", "-", "-", "-",
            "A#4", ".", ".", ".", "-", "-", "-", "-", "C5", ".", ".", ".", "-", "-", "-", "-"]
    drums = {"k": [0, 8], "h": [4, 12]}
    return build_song(110, 8, bass, lead, harm, drums, lead_kind="tri", harm_kind="tri",
                      lead_vol=0.23)

def music_metro():
    bass = ["A1", "-", "A1", "-", "A1", "-", "A1", "-", "G1", "-", "G1", "-", "A1", "-", "-", "-",
            "F1", "-", "F1", "-", "F1", "-", "G1", "-", "A1", "-", "-", "-", "E2", "-", "-", "-"]
    lead = ["A4", "-", "-", "E4", "-", "G4", "-", "-", "A4", "-", "-", "-", "-", "-", "-", "-",
            "C5", "-", "-", "B4", "-", "A4", "-", "-", "G4", "-", "E4", "-", "-", "-", "-", "-"]
    harm = ["E4", ".", ".", ".", ".", ".", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-",
            "F4", ".", ".", ".", ".", ".", "-", "-", "G4", ".", ".", ".", "-", "-", "-", "-"]
    drums = {"k": [0, 3, 4, 8, 11, 12], "s": [4, 12],
             "h": [0, 1, 2, 4, 6, 8, 9, 10, 12, 14], "t": [15]}
    return build_song(142, 8, bass, lead, harm, drums, lead_kind="square", harm_kind="tri",
                      lead_vol=0.27)

MUSIC = {
    "title": music_title, "street": music_street, "market": music_market, "alley": music_alley,
    "industrial": music_industrial, "boss": music_boss, "victory": music_victory, "shop": music_shop,
    "metro": music_metro, "battle": music_battle, "tension": music_tension,
}

# ----------------------------------------------------------------------
# Ambience
# ----------------------------------------------------------------------
def amb_city(dur=8.0, seed=101):
    rnd = random.Random(seed)
    n = int(dur * SR)
    out = [0.0] * n
    prev = 0.0
    for i in range(n):
        v = rnd.uniform(-1, 1)
        prev = prev + (v - prev) * 0.02
        out[i] = prev * 0.5
    # distant traffic swells
    for _ in range(9):
        at = rnd.uniform(0, dur - 1.2)
        sw = []
        m = int(1.1 * SR)
        p2 = 0.0
        for i in range(m):
            v = rnd.uniform(-1, 1)
            p2 = p2 + (v - p2) * 0.06
            sw.append(p2 * math.sin(math.pi * i / m) * 0.4)
        overlay(out, sw, at)
    return normalize(lowpass(out, 0.25), 0.32)

def amb_alley(dur=8.0):
    base = amb_city(dur, 202)
    rnd = random.Random(303)
    for _ in range(6):
        at = rnd.uniform(0, dur - 0.5)
        overlay(base, [v * 0.25 for v in tone(rnd.choice([900, 1200, 1500]), 0.18, "sine", 0.2, 12)], at)
    return normalize(base, 0.28)

def amb_interior(dur=8.0):
    rnd = random.Random(404)
    n = int(dur * SR)
    out = [0.0] * n
    prev = 0.0
    for i in range(n):
        v = rnd.uniform(-1, 1)
        prev = prev + (v - prev) * 0.012
        out[i] = prev * 0.45 + 0.05 * math.sin(math.tau * 60 * i / SR)
    return normalize(lowpass(out, 0.18), 0.22)

def amb_industrial(dur=8.0):
    base = amb_city(dur, 505)
    rnd = random.Random(606)
    for k in range(10):
        at = k * 0.8 + rnd.uniform(0, 0.2)
        if at > dur - 0.3:
            break
        overlay(base, [v * 0.3 for v in mix(noise_burst(0.12, 0.4, 18, lp=0.5, seed=700 + k), tone(140, 0.14, "square", 0.2, 16))], at)
    return normalize(base, 0.3)

def amb_river(dur=8.0):
    rnd = random.Random(707)
    n = int(dur * SR)
    out = [0.0] * n
    prev = 0.0
    for i in range(n):
        v = rnd.uniform(-1, 1)
        prev = prev + (v - prev) * 0.05
        mod = 0.6 + 0.4 * math.sin(math.tau * 0.28 * i / SR)
        out[i] = prev * 0.45 * mod
    return normalize(lowpass(out, 0.35), 0.26)

AMBIENCE = {"city": amb_city, "alley": amb_alley, "interior": amb_interior, "industrial": amb_industrial, "river": amb_river}

# ----------------------------------------------------------------------
def main():
    for name, fn in SFX.items():
        write_wav(os.path.join(SFX_DIR, f"{name}.wav"), fn())
    print(f"sfx: {len(SFX)}")
    for name, fn in MUSIC.items():
        write_wav(os.path.join(MUS_DIR, f"{name}.wav"), fn(), loop=True)
    print(f"music: {len(MUSIC)}")
    for name, fn in AMBIENCE.items():
        write_wav(os.path.join(AMB_DIR, f"{name}.wav"), fn(), loop=True)
    print(f"ambience: {len(AMBIENCE)}")

if __name__ == "__main__":
    main()

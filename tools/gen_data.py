#!/usr/bin/env python3
"""
Sidewalk Kings - content data generator.

Writes every gameplay .tres resource (moves, enemies, food, books, items, weapons, shops,
quests, dialogue, encounters, area metadata). Balance and writing live here in one place;
the engine only reads the generated resources.

Run from the project root:  python tools/gen_data.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SCRIPTS = {
    "MoveData": "res://combat/MoveData.gd",
    "EnemyData": "res://actors/enemies/EnemyData.gd",
    "FoodData": "res://data/FoodData.gd",
    "BookData": "res://data/BookData.gd",
    "ItemData": "res://data/ItemData.gd",
    "WeaponData": "res://weapons/WeaponData.gd",
    "ShopData": "res://data/ShopData.gd",
    "QuestData": "res://data/QuestData.gd",
    "DialogueData": "res://data/DialogueData.gd",
    "EncounterData": "res://data/EncounterData.gd",
    "AreaData": "res://data/AreaData.gd",
}

# ---------------------------------------------------------------------------
# .tres writing
# ---------------------------------------------------------------------------
def gd(value):
    """Serialise a Python value into Godot resource syntax."""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int,)):
        return str(value)
    if isinstance(value, float):
        return repr(value)
    if isinstance(value, str):
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'
    if isinstance(value, tuple):
        if len(value) == 2:
            return "Vector2(%s, %s)" % (float(value[0]), float(value[1]))
        if len(value) == 4:
            return "Color(%s, %s, %s, %s)" % tuple(float(v) for v in value)
    if isinstance(value, list):
        if value and all(isinstance(v, str) for v in value):
            return 'Array[String]([%s])' % ", ".join(gd(v) for v in value)
        if value and all(isinstance(v, dict) for v in value):
            return 'Array[Dictionary]([%s])' % ", ".join(gd(v) for v in value)
        return "[%s]" % ", ".join(gd(v) for v in value)
    if isinstance(value, dict):
        return "{%s}" % ", ".join("%s: %s" % (gd(k), gd(v)) for k, v in value.items())
    if value is None:
        return "null"
    raise ValueError("cannot serialise %r" % (value,))

class Ext:
    """Marker for an external resource reference (textures, sprite frames)."""
    def __init__(self, path, type_name="Texture2D"):
        self.path = path
        self.type = type_name

def write_tres(folder, name, script_class, props):
    ext = [(SCRIPTS[script_class], "Script")]
    for v in props.values():
        if isinstance(v, Ext):
            ext.append((v.path, v.type))
    lines = ['[gd_resource type="Resource" script_class="%s" load_steps=%d format=3]' % (script_class, len(ext) + 1), ""]
    ids = {}
    for i, (path, tname) in enumerate(ext, start=1):
        rid = "%d_%s" % (i, name.replace("-", "_"))
        ids[path] = rid
        lines.append('[ext_resource type="%s" path="%s" id="%s"]' % (tname, path, rid))
    lines.append("")
    lines.append("[resource]")
    lines.append('script = ExtResource("%s")' % ids[SCRIPTS[script_class]])
    for k, v in props.items():
        if isinstance(v, Ext):
            lines.append('%s = ExtResource("%s")' % (k, ids[v.path]))
        else:
            lines.append("%s = %s" % (k, gd(v)))
    out_dir = os.path.join(ROOT, "data", folder)
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, name + ".tres"), "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")

def sprite_frames(char):
    return Ext("res://assets/art/characters/%s_frames.tres" % char, "SpriteFrames")

def icon(name):
    return Ext("res://assets/art/ui/items/%s.png" % name)

def weapon_tex(name):
    return Ext("res://assets/art/weapons/%s.png" % name)

def portrait(char):
    return Ext("res://assets/art/ui/portraits/%s.png" % char)

# Enum shorthands (must match the GDScript enum order)
IN_NONE, IN_LIGHT, IN_HEAVY, IN_SPECIAL, IN_JUMP, IN_GRAB = range(6)
RQ_ANY, RQ_GROUND, RQ_AIR, RQ_RUN, RQ_GRABBING = range(5)
DK_PUNCH, DK_KICK, DK_THROW, DK_WEAPON, DK_SPECIAL, DK_BODY = range(6)
AR_GRUNT, AR_RUSHER, AR_GRAPPLER, AR_WEAPON, AR_HEAVY, AR_RANGED, AR_BOSS = range(7)
IK_CONSUM, IK_KEY, IK_BOOK, IK_EQUIP, IK_MISC = range(5)
SH_RESTAURANT, SH_STORE, SH_DOJO, SH_BOOKS, SH_WEAPONS, SH_CLOTHING = range(6)
OB_GANG, OB_ENEMY, OB_BOSS, OB_ITEM, OB_DELIVER, OB_TALK, OB_AREA, OB_FLAG = range(8)
WS_SWING, WS_BLUNT, WS_THROW, WS_BOUNCE = range(4)

# ===========================================================================
# MOVES
# ===========================================================================
def move(id, name, anim, **kw):
    p = dict(
        id=id, display_name=name, description="", animation=anim,
        input=IN_LIGHT, requirement=RQ_GROUND, damage_kind=DK_PUNCH,
        startup=4, active=3, recovery=8, cancel_window=14, hitstun=14,
        damage=6, knockback=(60.0, 0.0), launch_force=0.0, knockdown=False,
        energy_cost=0.0, special_cost=0.0, forward_move=0.0, self_launch=0.0,
        grab_target=False, multi_hit=1, armor=False,
        hitbox_offset=(18.0, -22.0), hitbox_size=(22.0, 30.0), lane_tolerance=13.0,
        followups=[], sound="whoosh_light", hit_sound="hit_light",
        screen_shake=0.0, hit_pause=0.04, hit_fx="spark_small", camera_kick=0.0,
        price=0, required_level=1, required_stat="", required_stat_value=0,
        required_move="", required_flag="", learnable=False,
    )
    p.update(kw)
    return p

MOVES = [
    # --- Core punch chain: three light hits that flow into a heavy finisher ---
    move("punch_1", "Jab", "punch1", damage=7, startup=3, active=3, recovery=9, hitstun=13,
         knockback=(52.0, 0.0), followups=["punch_2", "heavy", "uppercut"], sound="whoosh_light",
         hit_sound="hit_light", hit_pause=0.035, description="A fast opening jab."),
    move("punch_2", "Cross", "punch2", damage=8, startup=3, active=3, recovery=10, hitstun=14,
         knockback=(64.0, 0.0), followups=["punch_3", "heavy", "kick", "uppercut"],
         hit_pause=0.04, description="Straight right down the middle."),
    move("punch_3", "Body Hook", "punch3", damage=11, startup=4, active=4, recovery=14, hitstun=18,
         knockback=(105.0, 0.0), followups=["heavy", "kick", "spin_kick"], screen_shake=1.4,
         hit_pause=0.055, hit_fx="spark_big", hit_sound="hit_heavy", forward_move=42.0,
         description="Turns the hips over and digs into the ribs."),
    move("kick", "Roundhouse", "kick", damage=12, damage_kind=DK_KICK, input=IN_LIGHT,
         startup=6, active=4, recovery=15, hitstun=20, knockback=(120.0, 0.0),
         hitbox_offset=(22.0, -20.0), hitbox_size=(26.0, 30.0), screen_shake=1.6, hit_pause=0.055,
         hit_fx="spark_big", hit_sound="hit_heavy", sound="kick", followups=["heavy"],
         description="Long-reach kick that pushes them off you."),
    move("heavy", "Haymaker", "heavy", damage=17, input=IN_HEAVY, startup=9, active=4, recovery=20,
         hitstun=26, knockback=(180.0, 0.0), knockdown=True, launch_force=110.0,
         hitbox_offset=(23.0, -22.0), hitbox_size=(26.0, 32.0), screen_shake=3.2, hit_pause=0.085,
         hit_fx="spark_big", hit_sound="hit_heavy", sound="whoosh_heavy", forward_move=60.0,
         energy_cost=6.0, description="Slow, heavy, and it puts them on the pavement."),
    # --- Air & movement ---
    move("jump_kick", "Jump Kick", "jump_kick", damage=13, damage_kind=DK_KICK, input=IN_LIGHT,
         requirement=RQ_AIR, startup=3, active=8, recovery=6, hitstun=20, knockback=(120.0, 0.0),
         hitbox_offset=(20.0, -14.0), hitbox_size=(26.0, 34.0), screen_shake=1.6, hit_pause=0.05,
         hit_fx="spark_big", hit_sound="hit_heavy", sound="kick",
         description="Attack from the air. Beats grounded grabs."),
    move("jump_stomp", "Falling Stomp", "ground_stomp", damage=16, damage_kind=DK_KICK, input=IN_HEAVY,
         requirement=RQ_AIR, startup=4, active=8, recovery=12, hitstun=24, knockback=(80.0, 0.0),
         knockdown=True, hitbox_offset=(12.0, -8.0), hitbox_size=(24.0, 30.0), screen_shake=3.0,
         hit_pause=0.08, hit_fx="spark_big", hit_sound="hit_heavy", sound="whoosh_heavy",
         learnable=True, price=180, required_level=3,
         description="Drop both heels onto whoever is below."),
    move("run_attack", "Shoulder Charge", "run_attack", damage=15, damage_kind=DK_BODY,
         requirement=RQ_RUN, startup=4, active=6, recovery=16, hitstun=24, knockback=(170.0, 0.0),
         knockdown=True, hitbox_offset=(20.0, -20.0), hitbox_size=(26.0, 32.0), forward_move=150.0,
         screen_shake=2.6, hit_pause=0.07, hit_fx="spark_big", hit_sound="hit_heavy",
         sound="dash", description="Run at someone and put a shoulder through them."),
    # --- Grabs ---
    move("grab", "Grab", "grab", damage=0, input=IN_GRAB, grab_target=True, startup=4, active=4,
         recovery=10, hitstun=8, knockback=(0.0, 0.0), sound="grab", hit_sound="grab",
         description="Take hold of a staggered enemy."),
    move("grab_whiff", "Grab Attempt", "grab", damage=1, input=IN_GRAB, startup=4, active=3,
         recovery=12, hitstun=4, knockback=(10.0, 0.0), hitbox_offset=(16.0, -22.0),
         hitbox_size=(16.0, 26.0), sound="grab", description="Reach out and grab at someone."),
    move("grab_punch", "Held Knee", "grab_punch", damage=10, requirement=RQ_GRABBING, startup=2,
         active=2, recovery=6, hitstun=10, knockback=(0.0, 0.0), sound="punch_light",
         hit_sound="hit_light", hit_pause=0.06, screen_shake=1.2, hit_fx="spark_small",
         description="Work them over while you have hold of them."),
    move("throw", "Throw", "throw", damage=20, damage_kind=DK_THROW, requirement=RQ_GRABBING,
         startup=4, active=4, recovery=16, hitstun=34, knockback=(230.0, 0.0), knockdown=True,
         launch_force=200.0, screen_shake=3.4, hit_pause=0.08, hit_fx="spark_big",
         hit_sound="hit_heavy", sound="throw",
         description="Launch them down the street. They knock over whoever they hit."),
    move("back_throw", "Back Suplex", "throw", damage=28, damage_kind=DK_THROW,
         requirement=RQ_GRABBING, startup=6, active=4, recovery=22, hitstun=40,
         knockback=(150.0, 0.0), knockdown=True, launch_force=240.0, screen_shake=4.5,
         hit_pause=0.1, hit_fx="spark_big", hit_sound="hit_heavy", sound="throw",
         learnable=True, price=320, required_level=4, required_stat="strength", required_stat_value=9,
         description="Take them over backwards. Hurts a lot more than a plain throw."),
    # --- Dojo techniques ---
    move("uppercut", "Rising Uppercut", "uppercut", damage=19, input=IN_HEAVY, startup=6, active=5,
         recovery=20, hitstun=30, knockback=(80.0, 0.0), launch_force=250.0, knockdown=True,
         hitbox_offset=(16.0, -26.0), hitbox_size=(20.0, 44.0), screen_shake=3.0, hit_pause=0.08,
         hit_fx="spark_big", hit_sound="hit_heavy", sound="whoosh_heavy", energy_cost=10.0,
         learnable=True, price=200, required_level=2,
         description="Launches them straight up. Great for ending a light chain."),
    move("spin_kick", "Spin Kick", "spin_kick", damage=16, damage_kind=DK_KICK, input=IN_HEAVY,
         startup=8, active=6, recovery=18, hitstun=24, knockback=(150.0, 0.0), knockdown=True,
         hitbox_offset=(0.0, -22.0), hitbox_size=(52.0, 32.0), lane_tolerance=18.0,
         screen_shake=2.8, hit_pause=0.07, hit_fx="spark_big", hit_sound="hit_heavy",
         sound="whoosh_heavy", energy_cost=12.0, multi_hit=2,
         learnable=True, price=260, required_level=3, required_stat="technique", required_stat_value=7,
         description="Sweeps a full circle. Hits enemies on both sides."),
    move("flying_knee", "Flying Knee", "run_attack", damage=21, damage_kind=DK_KICK, input=IN_HEAVY,
         requirement=RQ_RUN, startup=5, active=7, recovery=18, hitstun=28, knockback=(190.0, 0.0),
         knockdown=True, self_launch=150.0, forward_move=190.0, hitbox_offset=(20.0, -16.0),
         hitbox_size=(26.0, 34.0), screen_shake=3.2, hit_pause=0.08, hit_fx="spark_big",
         hit_sound="hit_heavy", sound="dash", energy_cost=14.0,
         learnable=True, price=300, required_level=4, required_move="run_attack",
         description="Sprint, leap, and drive a knee through their guard."),
    move("power_punch", "Power Punch", "heavy", damage=26, input=IN_HEAVY, startup=13, active=4,
         recovery=24, hitstun=34, knockback=(240.0, 0.0), knockdown=True, launch_force=140.0,
         armor=True, hitbox_offset=(24.0, -22.0), hitbox_size=(28.0, 32.0), screen_shake=4.6,
         hit_pause=0.11, hit_fx="spark_big", hit_sound="hit_crit", sound="whoosh_heavy",
         energy_cost=18.0, learnable=True, price=420, required_level=5,
         required_stat="strength", required_stat_value=12, required_move="heavy",
         description="Wind all the way up. You shrug off small hits while you swing."),
    move("dash_strike", "Dash Strike", "dash", damage=14, startup=3, active=5, recovery=12,
         hitstun=18, knockback=(120.0, 0.0), forward_move=210.0, hitbox_offset=(18.0, -22.0),
         hitbox_size=(24.0, 30.0), screen_shake=1.8, hit_pause=0.05, hit_fx="spark_small",
         sound="dash", energy_cost=8.0, followups=["punch_1", "heavy"],
         learnable=True, price=190, required_level=2,
         description="Close distance instantly and open with a strike."),
    move("counter", "Counter Stance", "block", damage=18, input=IN_HEAVY, startup=2, active=14,
         recovery=14, hitstun=30, knockback=(160.0, 0.0), knockdown=True, armor=True,
         hitbox_offset=(16.0, -22.0), hitbox_size=(20.0, 30.0), screen_shake=3.0, hit_pause=0.09,
         hit_fx="spark_special", hit_sound="hit_crit", sound="block", energy_cost=15.0,
         learnable=True, price=380, required_level=4, required_stat="technique", required_stat_value=10,
         description="Hold your ground. Anyone who walks into it gets flattened."),
    move("ground_stomp", "Ground Stomp", "ground_stomp", damage=12, damage_kind=DK_KICK,
         input=IN_HEAVY, startup=5, active=4, recovery=14, hitstun=16, knockback=(40.0, 0.0),
         hitbox_offset=(14.0, -6.0), hitbox_size=(22.0, 20.0), screen_shake=2.0, hit_pause=0.06,
         hit_fx="dust", hit_sound="hit_heavy", sound="whoosh_heavy",
         description="Stomp on someone who is already down."),
    # --- Bex's school: Metro Line techniques ---
    move("turnstile_spin", "Turnstile Spin", "spin_kick", damage=14, damage_kind=DK_KICK, input=IN_HEAVY,
         startup=7, active=8, recovery=16, hitstun=22, knockback=(120.0, 0.0), knockdown=True,
         hitbox_offset=(0.0, -22.0), hitbox_size=(58.0, 32.0), lane_tolerance=20.0, multi_hit=3,
         screen_shake=2.6, hit_pause=0.06, hit_fx="spark_big", hit_sound="hit_heavy",
         sound="whoosh_heavy", energy_cost=13.0,
         learnable=True, price=280, required_level=4, required_move="spin_kick",
         description="A wider, faster spin. Clears a crowd off a platform edge."),
    move("platform_drop", "Platform Drop", "ground_stomp", damage=22, damage_kind=DK_KICK, input=IN_HEAVY,
         requirement=RQ_AIR, startup=5, active=8, recovery=16, hitstun=30, knockback=(110.0, 0.0),
         knockdown=True, hitbox_offset=(12.0, -8.0), hitbox_size=(30.0, 32.0), screen_shake=4.0,
         hit_pause=0.09, hit_fx="spark_big", hit_sound="hit_heavy", sound="whoosh_heavy",
         learnable=True, price=340, required_level=5, required_move="jump_stomp",
         description="Come down on them with everything. Best from a height."),
    move("closing_doors", "Closing Doors", "grab_punch", damage=16, damage_kind=DK_THROW,
         requirement=RQ_GRABBING, startup=3, active=3, recovery=12, hitstun=24, knockback=(60.0, 0.0),
         screen_shake=2.4, hit_pause=0.08, hit_fx="spark_big", hit_sound="hit_heavy",
         sound="punch_heavy", learnable=True, price=300, required_level=4, required_stat="strength",
         required_stat_value=10,
         description="Fold them shut. Heavier than a knee, and it keeps the grab."),
    move("last_train", "Last Train", "run_attack", damage=24, damage_kind=DK_BODY, input=IN_LIGHT,
         requirement=RQ_RUN, startup=5, active=7, recovery=20, hitstun=30, knockback=(220.0, 0.0),
         knockdown=True, forward_move=230.0, armor=True, hitbox_offset=(20.0, -20.0),
         hitbox_size=(28.0, 34.0), screen_shake=4.2, hit_pause=0.09, hit_fx="spark_special",
         hit_sound="hit_crit", sound="dash", energy_cost=16.0,
         learnable=True, price=420, required_level=6, required_move="run_attack",
         description="You are not stopping. Shrugs off small hits on the way through."),
    # --- Special ---
    move("special_burst", "Sidewalk Special", "special", damage=34, damage_kind=DK_SPECIAL,
         input=IN_SPECIAL, startup=10, active=8, recovery=22, hitstun=40, knockback=(230.0, 0.0),
         knockdown=True, launch_force=200.0, hitbox_offset=(0.0, -22.0), hitbox_size=(70.0, 44.0),
         lane_tolerance=24.0, screen_shake=6.0, hit_pause=0.12, hit_fx="spark_special",
         hit_sound="special_hit", sound="special_charge", special_cost=100.0, armor=True,
         description="Everything you have, all at once, in every direction."),
    # --- Weapons ---
    move("weapon_swing", "Weapon Swing", "weapon_swing", damage=14, damage_kind=DK_WEAPON,
         startup=6, active=5, recovery=16, hitstun=24, knockback=(150.0, 0.0),
         hitbox_offset=(24.0, -22.0), hitbox_size=(30.0, 32.0), screen_shake=2.2, hit_pause=0.06,
         hit_fx="spark_weapon", hit_sound="hit_weapon", sound="whoosh_heavy",
         description="Swing whatever you are holding."),
    move("weapon_swing_heavy", "Heavy Swing", "weapon_swing", damage=20, damage_kind=DK_WEAPON,
         startup=9, active=5, recovery=22, hitstun=30, knockback=(200.0, 0.0), knockdown=True,
         hitbox_offset=(25.0, -22.0), hitbox_size=(32.0, 34.0), screen_shake=3.4, hit_pause=0.08,
         hit_fx="spark_weapon", hit_sound="hit_weapon", sound="whoosh_heavy",
         description="A slower, meaner swing for heavy objects."),
    move("weapon_throw", "Weapon Throw", "throw_item", damage=16, damage_kind=DK_WEAPON,
         startup=5, active=4, recovery=14, hitstun=28, knockback=(190.0, 0.0), knockdown=True,
         hit_fx="spark_weapon", hit_sound="hit_weapon", sound="throw",
         description="Throw it at them instead."),
    move("body_collide", "Body Slam", "fall", damage=12, damage_kind=DK_BODY, startup=1, active=2,
         recovery=2, hitstun=30, knockback=(120.0, 0.0), knockdown=True, screen_shake=2.4,
         hit_pause=0.06, hit_fx="spark_big", hit_sound="hit_heavy",
         description="A thrown body knocking someone else over."),
    # --- Enemy moves ---
    move("enemy_jab", "Thug Jab", "punch1", damage=6, startup=8, active=3, recovery=16, hitstun=14,
         knockback=(60.0, 0.0), sound="whoosh_light", hit_sound="hit_light"),
    move("enemy_cross", "Thug Cross", "punch2", damage=8, startup=10, active=3, recovery=18,
         hitstun=16, knockback=(80.0, 0.0), sound="whoosh_light", hit_sound="hit_light"),
    move("enemy_kick", "Thug Kick", "kick", damage=9, damage_kind=DK_KICK, startup=12, active=4,
         recovery=20, hitstun=18, knockback=(110.0, 0.0), hitbox_offset=(21.0, -20.0),
         sound="kick", hit_sound="hit_light", screen_shake=1.0),
    move("enemy_heavy", "Thug Haymaker", "heavy", damage=14, startup=18, active=4, recovery=26,
         hitstun=26, knockback=(170.0, 0.0), knockdown=True, hitbox_offset=(23.0, -22.0),
         screen_shake=2.4, hit_pause=0.06, hit_fx="spark_big", hit_sound="hit_heavy",
         sound="whoosh_heavy", forward_move=40.0, telegraph=True),
    move("enemy_rush", "Rushing Tackle", "run_attack", damage=11, damage_kind=DK_BODY, startup=10,
         active=6, recovery=24, hitstun=22, knockback=(150.0, 0.0), knockdown=True,
         forward_move=160.0, screen_shake=2.0, hit_fx="spark_big", hit_sound="hit_heavy", sound="dash"),
    move("enemy_slam", "Heavy Slam", "ground_stomp", damage=18, damage_kind=DK_BODY, startup=24,
         active=5, recovery=30, hitstun=32, knockback=(150.0, 0.0), knockdown=True, armor=True,
         hitbox_offset=(18.0, -14.0), hitbox_size=(32.0, 34.0), screen_shake=4.0, hit_pause=0.07,
         hit_fx="spark_big", hit_sound="hit_heavy", sound="whoosh_heavy", telegraph=True),
    move("enemy_grab_hit", "Shove", "throw", damage=12, damage_kind=DK_THROW, startup=2, active=2,
         recovery=14, hitstun=30, knockback=(180.0, 0.0), knockdown=True, screen_shake=2.6,
         hit_fx="spark_big", hit_sound="hit_heavy", sound="throw"),
    move("enemy_throw_rock", "Thrown Junk", "throw_item", damage=8, damage_kind=DK_WEAPON,
         startup=14, active=4, recovery=22, hitstun=18, knockback=(90.0, 0.0),
         hit_fx="spark_small", hit_sound="hit_weapon", sound="throw"),
    move("enemy_weapon_swing", "Enemy Swing", "weapon_swing", damage=13, damage_kind=DK_WEAPON,
         startup=14, active=5, recovery=24, hitstun=24, knockback=(150.0, 0.0),
         hitbox_offset=(24.0, -22.0), hitbox_size=(30.0, 32.0), screen_shake=2.0,
         hit_fx="spark_weapon", hit_sound="hit_weapon", sound="whoosh_heavy"),
    # --- Boss moves ---
    move("boss_jab", "Starch Jab", "punch1", damage=10, startup=9, active=3, recovery=15,
         hitstun=16, knockback=(80.0, 0.0), sound="whoosh_light", hit_sound="hit_light"),
    move("boss_combo", "Pressed Cuff", "punch2", damage=13, startup=10, active=3, recovery=16,
         hitstun=18, knockback=(100.0, 0.0), sound="whoosh_light", hit_sound="hit_heavy",
         screen_shake=1.4),
    move("boss_kick", "Boot Polish", "kick", damage=15, damage_kind=DK_KICK, startup=13, active=4,
         recovery=20, hitstun=22, knockback=(150.0, 0.0), hitbox_offset=(24.0, -20.0),
         screen_shake=2.0, hit_fx="spark_big", hit_sound="hit_heavy", sound="kick"),
    move("boss_slam", "Pressing Slam", "ground_stomp", damage=24, damage_kind=DK_BODY, startup=16,
         active=6, recovery=34, hitstun=40, knockback=(200.0, 0.0), knockdown=True, armor=True,
         hitbox_offset=(16.0, -12.0), hitbox_size=(46.0, 36.0), lane_tolerance=22.0,
         screen_shake=6.0, hit_pause=0.1, hit_fx="spark_special", hit_sound="special_hit",
         sound="whoosh_heavy", description="The big telegraphed one. Get out of the way.", telegraph=True),
    move("boss_rush", "Laundry Run", "run_attack", damage=18, damage_kind=DK_BODY, startup=12,
         active=8, recovery=26, hitstun=30, knockback=(200.0, 0.0), knockdown=True,
         forward_move=260.0, screen_shake=3.6, hit_pause=0.07, hit_fx="spark_big",
         hit_sound="hit_heavy", sound="dash", telegraph=True),
]

# ===========================================================================
# ENEMIES
# ===========================================================================
def enemy(id, name, gang, char, arch, **kw):
    p = dict(
        id=id, display_name=name, gang=gang, archetype=arch,
        sprite_frames=sprite_frames(char), portrait=portrait(char),
        max_hp=30, damage_multiplier=1.0, defense=0.0, move_speed=70.0, run_speed=130.0,
        weight=1.0, armor_threshold=0, grab_resist=0.0, can_be_grabbed=True,
        preferred_distance=30.0, aggression=0.5, reaction_delay=0.35, attack_cooldown=1.1,
        circle_chance=0.4, picks_up_weapons=False, ranged_distance=140.0,
        moves=["enemy_jab", "enemy_kick"], heavy_move="", ranged_move="",
        xp=8, money_min=3, money_max=9, drop_table=[], drop_chance=0.12,
        scale=1.0, tint=(1.0, 1.0, 1.0, 1.0), show_health_bar=True,
        taunts=["You picked the wrong block."], defeat_lines=["...ow."],
    )
    p.update(kw)
    return p

ENEMIES = [
    enemy("pigeon_grunt", "Pigeon", "pigeons", "pigeon_grunt", AR_GRUNT,
          max_hp=26, move_speed=64.0, aggression=0.42, attack_cooldown=1.25, xp=8,
          money_min=4, money_max=10, drop_table=["rice_ball"], drop_chance=0.14,
          taunts=["You picked the wrong alley.", "This block's ours, pal.", "Hey! No loitering!"],
          defeat_lines=["Worth it.", "Tell nobody.", "I have a bus to catch."]),
    enemy("pigeon_rusher", "Skimmer", "pigeons", "pigeon_rusher", AR_RUSHER,
          max_hp=22, move_speed=98.0, run_speed=178.0, weight=0.8, preferred_distance=26.0,
          aggression=0.72, reaction_delay=0.2, attack_cooldown=0.8, circle_chance=0.2,
          moves=["enemy_jab", "enemy_rush"], xp=10, money_min=5, money_max=12,
          taunts=["Too slow!", "Catch me!"], defeat_lines=["Ran out of road."]),
    enemy("sweater_grunt", "Knit", "sweaters", "sweater_grunt", AR_GRUNT,
          max_hp=34, move_speed=70.0, defense=1.0, aggression=0.5, attack_cooldown=1.1,
          moves=["enemy_jab", "enemy_cross", "enemy_kick"], heavy_move="enemy_heavy",
          xp=12, money_min=6, money_max=14, drop_table=["skewer"], drop_chance=0.16,
          taunts=["Nice jacket. Hand it over.", "You are standing in our market."],
          defeat_lines=["My sweater...", "Fine. Fine!"]),
    enemy("sweater_grappler", "Big Knit", "sweaters", "sweater_grappler", AR_GRAPPLER,
          max_hp=58, move_speed=58.0, weight=1.6, defense=2.0, preferred_distance=22.0,
          aggression=0.6, attack_cooldown=1.5, circle_chance=0.15, grab_resist=0.5,
          moves=["enemy_cross", "enemy_kick"], heavy_move="enemy_heavy",
          xp=20, money_min=12, money_max=22, drop_table=["hot_soup"], drop_chance=0.2,
          scale=1.08, taunts=["Come here.", "Little guy."], defeat_lines=["Big mistake...on my part."]),
    enemy("grease_grunt", "Sprocket", "grease", "grease_grunt", AR_GRUNT,
          max_hp=38, move_speed=76.0, defense=1.0, aggression=0.58, attack_cooldown=1.0,
          moves=["enemy_jab", "enemy_cross", "enemy_kick"], heavy_move="enemy_heavy",
          xp=15, money_min=8, money_max=18, drop_table=["cold_noodles"], drop_chance=0.15,
          taunts=["Alley's closed.", "Watch the paint."], defeat_lines=["Oil everywhere..."]),
    enemy("grease_weapon", "Wrench", "grease", "grease_weapon", AR_WEAPON,
          max_hp=40, move_speed=72.0, aggression=0.55, attack_cooldown=1.2, picks_up_weapons=True,
          moves=["enemy_jab", "enemy_kick"], heavy_move="enemy_heavy",
          xp=18, money_min=10, money_max=20, drop_table=["energy_drink"], drop_chance=0.2,
          taunts=["I got tools for this.", "Hold still."], defeat_lines=["Dropped my wrench."]),
    enemy("rust_ranged", "Slinger", "rust_rats", "rust_ranged", AR_RANGED,
          max_hp=28, move_speed=80.0, run_speed=140.0, weight=0.85, preferred_distance=110.0,
          ranged_distance=190.0, aggression=0.6, attack_cooldown=1.6, circle_chance=0.5,
          moves=["enemy_jab"], ranged_move="enemy_throw_rock",
          xp=16, money_min=9, money_max=18, drop_table=["candy_bar"], drop_chance=0.18,
          taunts=["Heads up!", "Incoming!"], defeat_lines=["Out of ammo."]),
    enemy("rust_heavy", "Girder", "rust_rats", "rust_heavy", AR_HEAVY,
          max_hp=86, move_speed=48.0, run_speed=76.0, weight=2.2, defense=3.0,
          armor_threshold=12, preferred_distance=26.0, aggression=0.5, reaction_delay=0.5,
          attack_cooldown=2.0, circle_chance=0.1, can_be_grabbed=False,
          moves=["enemy_cross", "enemy_kick"], heavy_move="enemy_slam",
          xp=34, money_min=20, money_max=36, drop_table=["steel_lunch"], drop_chance=0.3,
          scale=1.12, taunts=["Yard's closed.", "You are very small."],
          defeat_lines=["Timber.", "I felt that one."]),
    enemy("cleaner_elite", "Pressman", "cleaners", "cleaner_elite", AR_GRUNT,
          max_hp=52, move_speed=88.0, run_speed=150.0, defense=2.0, preferred_distance=30.0,
          aggression=0.68, reaction_delay=0.25, attack_cooldown=0.9,
          moves=["enemy_jab", "enemy_cross", "enemy_kick"], heavy_move="enemy_heavy",
          xp=26, money_min=16, money_max=30, drop_table=["pressed_sandwich"], drop_chance=0.22,
          taunts=["This is a private matter.", "You are making a mess."],
          defeat_lines=["Unacceptable.", "I'll need to file that."]),
    enemy("cleaner_grappler", "Folder", "cleaners", "cleaner_grappler", AR_GRAPPLER,
          max_hp=70, move_speed=62.0, weight=1.7, defense=2.0, preferred_distance=22.0,
          aggression=0.62, attack_cooldown=1.4, grab_resist=0.6,
          moves=["enemy_cross", "enemy_kick"], heavy_move="enemy_heavy",
          xp=30, money_min=18, money_max=34, drop_table=["hot_soup"], drop_chance=0.25,
          scale=1.08, taunts=["Fold nicely.", "Hold still, please."],
          defeat_lines=["Creased.", "Send it through again."]),
    # ---- The Commuters: Metro Line and Bellwater ----
    enemy("commuter_grunt", "Straphanger", "commuters", "commuter_grunt", AR_GRUNT,
          max_hp=46, move_speed=74.0, defense=2.0, aggression=0.55, attack_cooldown=1.0,
          moves=["enemy_jab", "enemy_cross", "enemy_kick"], heavy_move="enemy_heavy",
          xp=22, money_min=14, money_max=26, drop_table=["platform_coffee"], drop_chance=0.18,
          taunts=["This is my carriage.", "Mind the gap. Please.", "You are in the way."],
          defeat_lines=["I will get the next one.", "...missed it."]),
    enemy("commuter_rusher", "Sprinter", "commuters", "commuter_rusher", AR_RUSHER,
          max_hp=32, move_speed=112.0, run_speed=196.0, weight=0.75, preferred_distance=24.0,
          aggression=0.78, reaction_delay=0.18, attack_cooldown=0.7, circle_chance=0.2,
          moves=["enemy_jab", "enemy_rush"], xp=20, money_min=12, money_max=24,
          taunts=["Hold the door!", "Move, move, move!"], defeat_lines=["Missed it anyway."]),
    enemy("commuter_grappler", "Turnstile", "commuters", "commuter_grappler", AR_GRAPPLER,
          max_hp=74, move_speed=60.0, weight=1.7, defense=3.0, preferred_distance=22.0,
          aggression=0.62, attack_cooldown=1.4, grab_resist=0.6,
          moves=["enemy_cross", "enemy_kick"], heavy_move="enemy_heavy",
          xp=32, money_min=20, money_max=36, drop_table=["hot_soup"], drop_chance=0.24,
          scale=1.08, taunts=["No ticket.", "One at a time."], defeat_lines=["Barrier is open."]),
    enemy("commuter_ranged", "Busker", "commuters", "commuter_ranged", AR_RANGED,
          max_hp=34, move_speed=86.0, run_speed=148.0, weight=0.8, preferred_distance=120.0,
          ranged_distance=200.0, aggression=0.62, attack_cooldown=1.5, circle_chance=0.5,
          moves=["enemy_jab"], ranged_move="enemy_throw_rock",
          xp=24, money_min=16, money_max=30, drop_table=["candy_bar"], drop_chance=0.2,
          taunts=["Requests cost extra.", "This one is called Leave."],
          defeat_lines=["Rough crowd."]),
    enemy("commuter_heavy", "The Conductor", "commuters", "commuter_heavy", AR_HEAVY,
          max_hp=110, move_speed=52.0, run_speed=84.0, weight=2.3, defense=4.0,
          armor_threshold=14, preferred_distance=28.0, aggression=0.55, reaction_delay=0.45,
          attack_cooldown=1.9, circle_chance=0.1, can_be_grabbed=False,
          moves=["enemy_cross", "enemy_kick"], heavy_move="enemy_slam",
          xp=44, money_min=28, money_max=48, drop_table=["steel_lunch"], drop_chance=0.32,
          scale=1.14, taunts=["Tickets.", "This service is not for you."],
          defeat_lines=["Terminating here.", "All change."]),
    enemy("big_starch", "Big Starch", "cleaners", "big_starch", AR_BOSS,
          max_hp=340, move_speed=68.0, run_speed=132.0, weight=2.6, defense=4.0,
          armor_threshold=14, preferred_distance=34.0, aggression=0.6, reaction_delay=0.35,
          attack_cooldown=1.4, circle_chance=0.25, can_be_grabbed=False,
          moves=["boss_jab", "boss_combo", "boss_kick"], heavy_move="boss_slam",
          xp=160, money_min=0, money_max=0, scale=1.2, show_health_bar=False,
          taunts=["You are getting the floor dirty."],
          defeat_lines=["...everything I own is white."]),
]

# ===========================================================================
# FOOD (10+)
# ===========================================================================
def food(id, name, price, heal, desc, icon_name, **kw):
    p = dict(id=id, display_name=name, price=price, heal=heal, energy=0,
             strength_bonus=0, defense_bonus=0, speed_bonus=0, stamina_bonus=0,
             technique_bonus=0, luck_bonus=0, max_hp_bonus=0, description=desc,
             icon=icon(icon_name), takeout=False, eat_line="")
    p.update(kw)
    return p

FOODS = [
    food("rice_ball", "Corner Rice Ball", 8, 22, "Wrapped in wax paper by someone in a hurry.", "sandwich",
         takeout=True, stamina_bonus=0, eat_line="Still warm. Mostly."),
    food("hot_noodles", "Bowl of Hot Noodles", 26, 55, "Mae's house bowl. The broth is a family secret and the secret is patience.", "noodles",
         stamina_bonus=1, max_hp_bonus=3, eat_line="That is a real bowl of noodles."),
    food("cold_noodles", "Yesterday's Noodles", 10, 20, "Cold, chewy, oddly satisfying. No refunds.", "noodles",
         takeout=True, eat_line="Texture: bold."),
    food("skewer", "Mystery Skewer", 14, 30, "Three cubes of something, grilled with confidence.", "skewer",
         takeout=True, strength_bonus=1, eat_line="Protein? Probably."),
    food("hot_soup", "Furnace Soup", 30, 60, "So hot it is legally a hazard. Builds character and blisters.", "soup",
         defense_bonus=1, max_hp_bonus=4, takeout=True, eat_line="Ow. Worth it."),
    food("energy_drink", "Amp Fizz", 18, 8, "Tastes like a battery that went to art school.", "drink",
         energy=40, speed_bonus=1, takeout=True, eat_line="Everything is faster now."),
    food("candy_bar", "Sidewalk Bar", 6, 14, "Found in every corner store, loved by nobody, eaten by everyone.", "candy",
         takeout=True, luck_bonus=0, eat_line="Sweet. Chalky. Fine."),
    food("pressed_sandwich", "Pressed Sandwich", 22, 42, "Flattened to perfection. The laundromat next door swears it is a coincidence.", "sandwich",
         defense_bonus=1, takeout=True, eat_line="Very flat. Very good."),
    food("steel_lunch", "Steelworker's Lunch", 40, 75, "Two of everything. Built for a twelve-hour shift.", "burger",
         strength_bonus=1, stamina_bonus=1, max_hp_bonus=6, eat_line="Now that is lunch."),
    food("morning_donut", "Day-Old Donut", 5, 12, "The glaze has fused into a protective shell.", "donut",
         takeout=True, eat_line="Crunchy in an unexpected way."),
    food("river_coffee", "Ferry Coffee", 9, 6, "Brewed at 4am for people who have been awake since 3.", "coffee",
         energy=30, technique_bonus=0, takeout=True, eat_line="Awake. Deeply awake."),
    food("victory_cone", "Victory Cone", 16, 34, "Auntie Mae gives these out after a good day. She decides what counts.", "icecream",
         luck_bonus=1, takeout=True, eat_line="Earned it."),
    food("platform_coffee", "Platform Coffee", 11, 10, "Brewed at the far end of the platform by a machine that has seen things.", "coffee",
         energy=34, takeout=True, eat_line="Bitter. Effective."),
    food("bellwater_stew", "Bellwater Stew", 34, 66, "Whatever was in the cupboard, cooked until it agreed to get along.", "soup",
         defense_bonus=1, stamina_bonus=1, max_hp_bonus=5, eat_line="Tastes like somebody grandmother made it."),
    food("lost_sandwich", "Lost Property Sandwich", 7, 16, "Handed in on Tuesday. Nobody has claimed it. It is still technically food.", "sandwich",
         takeout=True, luck_bonus=1, eat_line="A gamble that paid off."),
    food("slice", "Corner Slice", 20, 45, "Folded, never cut. Arguing about this is a local sport.", "pizza",
         stamina_bonus=1, takeout=True, eat_line="Fold it. Always fold it."),
]

# ===========================================================================
# BOOKS
# ===========================================================================
def book(id, name, price, desc, blurb, **kw):
    p = dict(id=id, display_name=name, price=price, description=desc, blurb=blurb,
             unlock_move="", stat="", stat_bonus=0, bonus="", bonus_amount=0,
             required_level=1, icon=icon("book_red"))
    p.update(kw)
    return p

BOOKS = [
    book("street_physics", "Street Physics", 140,
         "Momentum, leverage, and why the pavement always wins.",
         "Chapter 4 is just a diagram of a man falling over.",
         stat="technique", stat_bonus=2, bonus="throw_damage", bonus_amount=1, icon=icon("book_blue")),
    book("punching_above", "Punching Above Your Weight", 180,
         "How smaller fighters generate real power.",
         "The author is 5'4\" and extremely confident.",
         bonus="punch_damage", bonus_amount=2, stat="strength", stat_bonus=1, icon=icon("book_red")),
    book("legal_throwing", "The Surprisingly Legal Art of Throwing People", 260,
         "A hands-on guide to putting someone down safely. For them, mostly.",
         "Includes a foreword by a very tired paramedic.",
         unlock_move="back_throw", required_level=3, icon=icon("book_gold")),
    book("footwork", "Footwork for People Who Hate Running", 150,
         "Efficient movement for the chronically unenthusiastic.",
         "Step one: stop flailing. Step two: there is no step two.",
         stat="speed", stat_bonus=2, bonus="move_speed", bonus_amount=4, icon=icon("book_green")),
    book("breathing", "Breathing Is Free, Use It", 120,
         "Stamina work that costs nothing and hurts anyway.",
         "Half the pages are just the word 'exhale'.",
         stat="stamina", stat_bonus=2, bonus="stamina_recovery", bonus_amount=2, icon=icon("book_green")),
    book("lucky_pockets", "Lucky Pockets", 200,
         "On finding money in the street and other minor miracles.",
         "Statistically dubious. Practically effective.",
         stat="luck", stat_bonus=3, bonus="crit_chance", bonus_amount=1, icon=icon("book_gold")),
    book("hard_head", "Hard Head, Soft Landing", 170,
         "Taking a hit without letting it take you.",
         "The cover is dented.",
         stat="defense", stat_bonus=2, bonus="max_hp", bonus_amount=10, icon=icon("book_blue")),
    book("swing_theory", "Swing Theory", 210,
         "Getting the most out of found objects.",
         "Legally distinct from a manual on assault.",
         bonus="weapon_skill", bonus_amount=2, required_level=2, icon=icon("book_red")),
]

# ===========================================================================
# ITEMS (key items and non-food consumables)
# ===========================================================================
def item(id, name, kind, desc, **kw):
    p = dict(id=id, display_name=name, description=desc, kind=kind, price=10,
             icon=icon("letter"), heal=0, energy=0, stackable=True,
             usable_in_field=True, flag_on_use="")
    p.update(kw)
    return p

ITEMS = [
    item("dojo_flyer", "Crumpled Dojo Flyer", IK_KEY,
         "A photocopy of a photocopy. 'FREE FIRST LESSON' is crossed out and rewritten twice.",
         icon=icon("flyer"), stackable=False),
    item("stolen_backpack", "Stolen Backpack", IK_KEY,
         "A student's backpack. Heavy with textbooks and one very sad sandwich.",
         icon=icon("backpack"), stackable=False),
    item("laundry_ticket", "Laundry Ticket #0", IK_KEY,
         "Numbered zero. The Cleaners hand these out to people who owe them something.",
         icon=icon("letter"), stackable=False),
    item("bandage", "Corner Store Bandage", IK_CONSUM,
         "Restores a bit of health. Adhesive quality: aspirational.",
         price=12, heal=25, icon=icon("letter")),
    item("chalk", "Blue Chalk", IK_MISC,
         "Odell hands these out. He will not explain why.",
         price=5, icon=icon("letter")),
]

# ===========================================================================
# WEAPONS
# ===========================================================================
def weapon(id, name, tex, **kw):
    p = dict(id=id, display_name=name, texture=weapon_tex(tex), style=WS_SWING,
             damage=14, durability=6, breaks=True, swing_move="weapon_swing",
             throw_damage=16, throw_speed=320.0, weight=1.0, knockback=(140.0, 0.0),
             knockdown=False, hit_sound="hit_weapon", swing_sound="whoosh_heavy",
             break_sound="weapon_break", hand_offset=(14.0, -26.0),
             rotation_degrees_held=-35.0, bounces_on_throw=False, shop_price=0)
    p.update(kw)
    return p

WEAPONS = [
    weapon("bat", "Cracked Bat", "bat", damage=20, durability=10, throw_damage=20,
           knockback=(190.0, 0.0), knockdown=True, shop_price=120),
    weapon("pipe", "Length of Pipe", "pipe", damage=18, durability=12, throw_damage=18,
           knockback=(170.0, 0.0), shop_price=95),
    weapon("plank", "Loose Plank", "plank", damage=16, durability=5, throw_damage=14,
           knockback=(160.0, 0.0), knockdown=True),
    weapon("bottle", "Empty Bottle", "bottle", damage=11, durability=2, throw_damage=15,
           knockback=(100.0, 0.0), hand_offset=(12.0, -28.0), rotation_degrees_held=-15.0),
    weapon("brick", "Loose Brick", "brick", damage=13, durability=3, throw_damage=20,
           knockback=(120.0, 0.0), throw_speed=380.0, hand_offset=(12.0, -26.0),
           rotation_degrees_held=0.0),
    weapon("chair", "Folding Chair", "chair", damage=24, durability=4, swing_move="weapon_swing_heavy",
           throw_damage=22, knockback=(210.0, 0.0), knockdown=True, weight=1.5,
           hand_offset=(16.0, -30.0), rotation_degrees_held=-55.0),
    weapon("cone", "Traffic Cone", "cone", damage=9, durability=-1, breaks=False,
           throw_damage=10, knockback=(90.0, 0.0), weight=0.6, hand_offset=(13.0, -28.0),
           rotation_degrees_held=-20.0, shop_price=25),
    weapon("basketball", "Lost Basketball", "basketball", style=WS_BOUNCE, damage=8, durability=-1,
           breaks=False, throw_damage=13, throw_speed=400.0, bounces_on_throw=True,
           knockback=(80.0, 0.0), weight=0.5, hand_offset=(12.0, -28.0), rotation_degrees_held=0.0),
    weapon("trash_lid", "Trash Can Lid", "trash_lid", damage=12, durability=14, throw_damage=14,
           knockback=(130.0, 0.0), hand_offset=(14.0, -26.0), rotation_degrees_held=-10.0,
           shop_price=45),
    weapon("mop", "Laundromat Mop", "mop", damage=15, durability=6, throw_damage=12,
           knockback=(150.0, 0.0), hand_offset=(15.0, -28.0), rotation_degrees_held=-40.0),
    weapon("trashcan_weapon", "Whole Trash Can", "trashcan_weapon", damage=26,
           swing_move="weapon_swing_heavy", durability=3, throw_damage=26, knockback=(220.0, 0.0),
           knockdown=True, weight=1.8, throw_speed=260.0, hand_offset=(18.0, -30.0),
           rotation_degrees_held=0.0),
]

# ===========================================================================
# SHOPS
# ===========================================================================
def shop(id, name, stype, owner, greeting, inventory, **kw):
    p = dict(id=id, display_name=name, shop_type=stype, owner_name=owner,
             owner_portrait=portrait("auntie_mae"), greeting=greeting,
             farewell="Come back soon.", broke_line="Come back when you have the money.",
             purchase_lines=["Good choice."], inventory=inventory, music="shop")
    p.update(kw)
    return p

SHOPS = [
    shop("mae_noodles", "Mae's Noodle Counter", SH_RESTAURANT, "Auntie Mae",
         "Sit. Eat. You look like a coat rack.",
         ["hot_noodles", "cold_noodles", "hot_soup", "skewer", "slice", "victory_cone"],
         owner_portrait=portrait("auntie_mae"),
         purchase_lines=["Eat it all.", "Chew. Do not inhale.", "Better already."],
         broke_line="Money first. I have heard every story."),
    shop("vic_corner", "Vic's Corner Store", SH_STORE, "Vic",
         "Hey! Everything's priced, don't ask for discounts.",
         ["rice_ball", "candy_bar", "morning_donut", "energy_drink", "river_coffee",
          "pressed_sandwich", "bandage"],
         owner_portrait=portrait("vic"),
         purchase_lines=["Cash only. Well. It's all cash.", "Bag's extra. Kidding.", "Nice."],
         broke_line="This is a store, not a library."),
    shop("odell_dojo", "Odell's Back Room Dojo", SH_DOJO, "Odell",
         "You want to learn or you want to look like you learned?",
         ["uppercut", "spin_kick", "dash_strike", "flying_knee", "counter", "power_punch", "jump_stomp"],
         owner_portrait=portrait("odell"),
         purchase_lines=["Again. Slower.", "Now you know it. Now go learn it.", "Good. Don't get smug."],
         broke_line="Training's not free. Neither is the mat."),
    shop("marisol_books", "Marisol's Stacks", SH_BOOKS, "Marisol",
         "Everything's used. Everything's underlined. Sorry.",
         ["street_physics", "punching_above", "footwork", "breathing", "hard_head",
          "swing_theory", "lucky_pockets", "legal_throwing"],
         owner_portrait=portrait("marisol"),
         purchase_lines=["Read the footnotes.", "That one's good. Weird, but good.", "No returns on wisdom."],
         broke_line="I take money, not enthusiasm."),
    shop("pops_gear", "Pops' Useful Objects", SH_WEAPONS, "Pops",
         "It's all legal. Mostly. It's all useful.",
         ["bat", "pipe", "trash_lid", "cone"],
         owner_portrait=portrait("pops"),
         purchase_lines=["Don't hit anything you like.", "It'll last. Probably.", "Handle with confidence."],
         broke_line="Look with your eyes, kid."),
    shop("bex_dojo", "Bex's Metro Line School", SH_DOJO, "Bex",
         "Down here you learn to fight in a space you cannot leave.",
         ["turnstile_spin", "platform_drop", "closing_doors", "last_train"],
         owner_portrait=portrait("bex"),
         purchase_lines=["Again, on the yellow line.", "Feet closer together.", "Good. Now do it tired."],
         broke_line="The lesson costs. The platform is free."),
    shop("nadia_store", "Nadia's Corner", SH_STORE, "Nadia",
         "Bellwater's only shop, which makes it the best one.",
         ["bellwater_stew", "platform_coffee", "lost_sandwich", "rice_ball", "bandage", "energy_drink"],
         owner_portrait=portrait("nadia"),
         purchase_lines=["Take it while it is hot.", "Tell your friends. Both of them."],
         broke_line="I run a shop, not a charity. Barely a shop."),
    shop("laundry_counter", "Starch & Sons Front Counter", SH_STORE, "Attendant",
         "We are... not really open to walk-ins.",
         ["bandage", "energy_drink", "pressed_sandwich"],
         owner_portrait=portrait("laundry_lady"),
         purchase_lines=["Please don't tell anyone you were here."],
         broke_line="Then please leave."),
]

# ===========================================================================
# QUESTS
# ===========================================================================
def quest(id, title, desc, objective, target, **kw):
    p = dict(id=id, title=title, description=desc, giver="", objective=objective,
             target=target, required_count=1, turn_in_npc="", reward_money=0,
             reward_xp=0, reward_items=[], reward_move="", reward_flag="",
             optional=True, hint="")
    p.update(kw)
    return p

QUESTS = [
    quest("q_pigeons", "Clear the Ferry Row", "Dez says the Pigeons have been shaking down the ferry queue. Convince five of them to find another block.",
          OB_GANG, "pigeons", required_count=5, giver="dez", turn_in_npc="dez",
          reward_money=60, reward_xp=40, optional=False, hint="Pigeons hang around Ferry Row.",
          reward_flag="q_pigeons_done"),
    quest("q_backpack", "The Very Heavy Backpack", "A student got jumped near the market and lost his backpack. It went into the alley.",
          OB_ITEM, "stolen_backpack", giver="student", turn_in_npc="student",
          reward_money=90, reward_xp=55, reward_items=["bandage"],
          hint="Someone in Grease Alley is sitting on it."),
    quest("q_flyer", "Free First Lesson", "Odell's dojo flyer blew off the wall. Find one and bring it back, and he might take you seriously.",
          OB_ITEM, "dojo_flyer", giver="odell", turn_in_npc="odell",
          reward_money=40, reward_xp=30, reward_move="dash_strike",
          hint="Try the bins around Lantern Market."),
    quest("q_soup", "Soup Delivery", "Auntie Mae wants a bowl of Furnace Soup taken to Pops before it cools. It will not cool.",
          OB_DELIVER, "hot_soup", giver="auntie_mae", turn_in_npc="pops",
          reward_money=70, reward_xp=35, reward_items=["victory_cone"],
          hint="Buy Furnace Soup at Mae's, then find Pops in Grease Alley."),
    quest("q_alley_boss", "Whoever Runs the Alley", "The Grease Monkeys answer to someone. Clear out the alley and find out who is paying them.",
          OB_FLAG, "alley_cleared", giver="dez", turn_in_npc="dez",
          reward_money=120, reward_xp=80, optional=False, reward_flag="knows_about_payer",
          hint="Fight your way through Grease Alley."),
    quest("q_yard", "Rust and Trouble", "The Rust Rats took the scrapyard. Nobody hired them either, which is exactly the problem.",
          OB_GANG, "rust_rats", required_count=6, giver="pops", turn_in_npc="pops",
          reward_money=140, reward_xp=95, reward_items=["steel_lunch"],
          hint="Rustpile Yard, past the alley."),
    quest("q_starch", "Big Starch", "Every gang in Riverbend has been paid in crisp, folded bills. There is one laundromat in this city that folds anything.",
          OB_BOSS, "big_starch", giver="dez", turn_in_npc="", required_count=1,
          reward_money=250, reward_xp=200, optional=False, reward_flag="chapter_1_done",
          hint="Starch & Sons, behind the yard."),
    quest("q_commuters", "Mind the Gap", "The Commuters run the metro line and never seem to get off it. Convince six of them to take a break.",
          OB_GANG, "commuters", required_count=6, giver="nadia", turn_in_npc="nadia",
          reward_money=180, reward_xp=120, reward_items=["bellwater_stew"],
          hint="They are all over the platform and Bellwater Block."),
    quest("q_tuesday", "Tuesday's Bag", "Somebody brings the money in on Tuesdays and never steps off the train. Find where they leave it.",
          OB_FLAG, "found_tuesday_locker", giver="dez", turn_in_npc="dez", optional=False,
          reward_money=220, reward_xp=160, reward_flag="knows_tuesday_route",
          hint="Search the metro platform. Try the lockers."),
    quest("q_roof", "The Long Way Round", "The kid on the roof says you can cross Bellwater without touching the street. Prove it.",
          OB_AREA, "bellwater_block", giver="roof_kid", turn_in_npc="roof_kid",
          reward_money=90, reward_xp=70, reward_items=["lost_sandwich"],
          hint="Take the fire escape out of Grease Alley and keep going."),
    quest("q_hungry", "Feed the Ferry Man", "The old ferry operator has not eaten since his shift started. His shift started Tuesday.",
          OB_DELIVER, "rice_ball", giver="old_ferry", turn_in_npc="old_ferry",
          reward_money=45, reward_xp=25, reward_items=["river_coffee"],
          hint="Rice balls are at Vic's Corner Store."),
]

# ===========================================================================
# DIALOGUE
# ===========================================================================
def L(name, text, portrait_id=None, **kw):
    d = {"name": name, "text": text}
    if portrait_id is not None:
        d["portrait"] = portrait_id
    d.update(kw)
    return d

DIALOGUES = {
# ---------------- Opening ----------------
"intro_ferry": dict(once_flag="seen_intro", lines=[
    L("", "Riverbend. Two years away, and the ferry still smells like diesel and fried dough."),
    L("Dez", "KIP! Hey! Over here!", "dez"),
    L("Kip", "Dez. You got taller.", "kip"),
    L("Dez", "I got *worried*. Different thing.", "dez"),
    L("Dez", "Four blocks, four crews. Pigeons on the row, Sweaters in the market, Grease Monkeys in the alley, Rust Rats in the yard.", "dez"),
    L("Kip", "Gangs fight each other. That's the whole point of gangs.", "kip"),
    L("Dez", "That's the thing. They stopped. Last month they all just... agreed. Split the map. No arguing.", "dez"),
    L("Kip", "Gangs don't agree.", "kip"),
    L("Dez", "Gangs don't agree for free.", "dez", set_flag="knows_premise", start_quest="q_pigeons"),
    L("Dez", "Start with the Pigeons. They're the loudest and the softest. Then come find me.", "dez", end=True),
]),
"dez_hub": dict(lines=[
    L("Dez", "Still standing. Good sign.", "dez"),
    L("Dez", "Whoever's paying them is paying on time. That's the part that bothers me.", "dez", end=True),
]),
"dez_pigeons_done": dict(lines=[
    L("Dez", "Five Pigeons found other hobbies. Nice.", "dez"),
    L("Kip", "One of them had forty dollars on him. Folded. Crisp.", "kip"),
    L("Dez", "Crisp?", "dez"),
    L("Kip", "Like it came out of a press.", "kip"),
    L("Dez", "Huh. Head up to Lantern Market. Talk to Mae, talk to Odell. Somebody's seen something.", "dez",
      complete_quest="q_pigeons", set_flag="market_opened", end=True),
]),
"dez_alley": dict(lines=[
    L("Dez", "Grease Alley next. They've got the least reason to be organised and the most gear.", "dez",
      start_quest="q_alley_boss", end=True),
]),
"dez_finale": dict(lines=[
    L("Dez", "A laundromat.", "dez"),
    L("Kip", "A laundromat.", "kip"),
    L("Dez", "That is either the dumbest lead we've had or the only one that explains crisp money.", "dez"),
    L("Kip", "It explains crisp money perfectly.", "kip"),
    L("Dez", "Go. I'll keep the lights on.", "dez", start_quest="q_starch", end=True),
]),
# ---------------- Boss ----------------
"starch_intro": dict(lines=[
    L("Big Starch", "You have tracked half the river across my floor.", "big_starch"),
    L("Kip", "You've been paying four gangs to sit still.", "kip"),
    L("Big Starch", "I have been paying four gangs to be *tidy*. There is a difference and you have never understood it.", "big_starch"),
    L("Kip", "Who's paying you?", "kip"),
    L("Big Starch", "Now that is a much better question. Ask it again when you can stand up.", "big_starch", end=True),
]),
"starch_defeat": dict(lines=[
    L("Big Starch", "...everything I own is white.", "big_starch"),
    L("Kip", "Who hired you?", "kip"),
    L("Big Starch", "Hired. Please. I was given a *route*. Money comes in on Tuesdays, in a bag, from the metro side.", "big_starch"),
    L("Kip", "Who brings it?", "kip"),
    L("Big Starch", "Someone who never gets off the train.", "big_starch"),
    L("Kip", "That's not an answer.", "kip"),
    L("Big Starch", "It is the answer I was paid for. Go home, kid. Riverbend is bigger than four blocks.", "big_starch",
      set_flag="chapter_1_done", end=True),
]),
# ---------------- Shops / NPCs ----------------
"mae_intro": dict(lines=[
    L("Auntie Mae", "You. Skinny. Sit.", "auntie_mae"),
    L("Kip", "I'm fine, Mae.", "kip"),
    L("Auntie Mae", "You are vertical. That is not the same as fine.", "auntie_mae"),
    L("Auntie Mae", "Sweaters came by. Asked for 'a contribution to the neighbourhood'. I gave them soup.", "auntie_mae"),
    L("Kip", "That was generous.", "kip"),
    L("Auntie Mae", "It was very hot soup.", "auntie_mae", set_flag="met_mae", start_quest="q_soup", shop="mae_noodles", end=True),
]),
"mae_shop": dict(lines=[L("Auntie Mae", "Sit. Eat. Then go be useful.", "auntie_mae", shop="mae_noodles", end=True)]),
"vic_intro": dict(lines=[
    L("Vic", "Whoa. Kip? Thought you moved.", "vic"),
    L("Kip", "I did. Then I came back.", "kip"),
    L("Vic", "Bold. Everything's priced. The chips are a lie, they're stale, buy the rice balls.", "vic", set_flag="met_vic", shop="vic_corner", end=True),
]),
"vic_shop": dict(lines=[L("Vic", "Rice balls are fresh. The rest is negotiable in spirit only.", "vic", shop="vic_corner", end=True)]),
"odell_intro": dict(lines=[
    L("Odell", "No.", "odell"),
    L("Kip", "I haven't asked anything.", "kip"),
    L("Odell", "You walked in with your shoulders up. The answer to that is always no.", "odell"),
    L("Kip", "I want to learn.", "kip"),
    L("Odell", "Everybody wants to learn. Bring me one of my flyers. I put up forty and I have zero. Show me you can find something.", "odell",
      set_flag="met_odell", start_quest="q_flyer", end=True),
]),
"odell_shop": dict(lines=[
    L("Odell", "Money on the mat, then we work.", "odell", shop="odell_dojo", end=True),
]),
"odell_flyer_done": dict(lines=[
    L("Odell", "Hm. This one's from the bins.", "odell"),
    L("Kip", "It was in a bin.", "kip"),
    L("Odell", "Good. Means you looked instead of asked.", "odell", complete_quest="q_flyer", shop="odell_dojo", end=True),
]),
"marisol_intro": dict(lines=[
    L("Marisol", "Careful, that stack is load-bearing.", "marisol"),
    L("Kip", "Are these all fight books?", "kip"),
    L("Marisol", "They're all *physics* books. Some of them are honest about it.", "marisol", set_flag="met_marisol", shop="marisol_books", end=True),
]),
"marisol_shop": dict(lines=[L("Marisol", "Read the footnotes. That's where the good stuff hides.", "marisol", shop="marisol_books", end=True)]),
"pops_intro": dict(lines=[
    L("Pops", "You're the one making noise on my street.", "pops"),
    L("Kip", "The Grease Monkeys were making noise. I made it stop.", "kip"),
    L("Pops", "Same volume from where I sit.", "pops"),
    L("Pops", "Rust Rats took my yard last week. If you're going that way, take something with a handle.", "pops",
      set_flag="met_pops", start_quest="q_yard", shop="pops_gear", end=True),
]),
"pops_shop": dict(lines=[L("Pops", "Everything here has been used at least once. Successfully.", "pops", shop="pops_gear", end=True)]),
"pops_soup": dict(lines=[
    L("Pops", "Is that from Mae?", "pops"),
    L("Kip", "It's still boiling.", "kip"),
    L("Pops", "It's always still boiling. Thirty years, that woman has never served a cool bowl.", "pops", end=True),
]),
# ---------------- Flavour NPCs ----------------
"student_intro": dict(lines=[
    L("Student", "They took my bag. My BAG. My whole semester is in that bag.", "student"),
    L("Kip", "Who did?", "kip"),
    L("Student", "Guys with wrenches. They went into the alley. They said the bag was 'evidence'. Evidence of WHAT? Chemistry?", "student"),
    L("Kip", "I'll get it.", "kip", start_quest="q_backpack", end=True),
]),
"student_done": dict(lines=[
    L("Student", "MY BAG. Oh, thank god. Is the sandwich still in there?", "student"),
    L("Kip", "Yes.", "kip"),
    L("Student", "Is it... okay?", "student"),
    L("Kip", "It's been through a lot. We all have.", "kip", end=True),
]),
"worker_line": dict(lines=[
    L("Worker", "Third week they've had the yard fenced off. Nobody's building anything. They're just standing there.", "worker"),
    L("Worker", "Getting paid to stand. I've been trying to get that job for eleven years.", "worker", end=True),
]),
"performer_line": dict(lines=[
    L("Street Performer", "You want to hear a song about a man who lost everything?", "performer"),
    L("Kip", "Not really.", "kip"),
    L("Street Performer", "Good, I only know the first line. It's very sad and then it stops.", "performer", end=True),
]),
"rumor_kid_line": dict(lines=[
    L("Kid", "You know the laundromat behind the yard?", "rumor_kid"),
    L("Kip", "No.", "kip"),
    L("Kid", "Nobody does. That's the weird part. It's ALWAYS open and nobody's ever got clean clothes from it.", "rumor_kid",
      set_flag="heard_laundromat_rumor", end=True),
]),
"old_ferry_intro": dict(lines=[
    L("Ferry Man", "Been on this dock since Tuesday.", "old_ferry"),
    L("Kip", "It's Friday.", "kip"),
    L("Ferry Man", "Is it.", "old_ferry"),
    L("Kip", "Have you eaten?", "kip"),
    L("Ferry Man", "That's a Tuesday question.", "old_ferry", start_quest="q_hungry", end=True),
]),
"old_ferry_done": dict(lines=[
    L("Ferry Man", "...oh, that's a rice ball.", "old_ferry"),
    L("Ferry Man", "Kid, when the crews stopped fighting? The ferry stopped being late. Whoever's running this is *organised*.", "old_ferry", end=True),
]),
"laundry_lady_line": dict(lines=[
    L("Attendant", "We're closed.", "laundry_lady"),
    L("Kip", "The sign says open.", "kip"),
    L("Attendant", "The sign is aspirational.", "laundry_lady", end=True),
]),
"auntie_wander": dict(lines=[L("Local", "Whole block's been quiet. Too quiet. I liked the arguing.", None, end=True)]),
# ---------------- Props / misc ----------------
"vending_broken": dict(lines=[L("", "The machine hums, takes your money, and gives you a look.", None, end=True)]),
"alley_note": dict(lines=[
    L("", "A note taped inside the dumpster lid:"),
    L("", "'ROUTE 4 - TUES. DO NOT COUNT IT IN FRONT OF THEM.'", None, set_flag="found_route_note", end=True),
]),
"metro_locked": dict(lines=[
    L("", "The metro gate is chained. Someone has laminated the 'CLOSED' sign, which suggests it has been closed for a while."),
    L("Kip", "Tuesdays.", "kip", end=True),
]),
# ---------------- Chapter two: the Metro Line ----------------
"dez_metro": dict(lines=[
    L("Dez", "You look like someone who has been told a laundromat is a front.", "dez"),
    L("Kip", "Money comes in Tuesdays. From the metro side. Carried by someone who never gets off the train.", "kip"),
    L("Dez", "That is either nonsense or the most useful thing anyone has said all year.", "dez"),
    L("Kip", "The gate is chained.", "kip"),
    L("Dez", "That gate has been chained since we were nine. The chain is decorative.", "dez",
      set_flag="metro_open", start_quest="q_tuesday", end=True),
]),
"metro_locked_ch2": dict(lines=[
    L("", "The chain hangs through the gate without actually joining either side of it."),
    L("Kip", "...huh.", "kip", end=True),
]),
"metro_arrival": dict(once_flag="seen_metro", lines=[
    L("", "Warm air, tile, and the particular quiet of a platform between trains."),
    L("Kip", "For a station nobody uses, somebody mops this floor.", "kip", end=True),
]),
"locker_found": dict(once_flag="found_tuesday_locker_seen", lines=[
    L("", "Locker 12. Unlocked. Empty, except for a paper band, the kind that goes round a stack of notes."),
    L("Kip", "Tuesday.", "kip"),
    L("", "Someone has written one word on the band in pencil: BELLWATER."),
    L("Kip", "That is not a name. That is an address.", "kip",
      set_flag="found_tuesday_locker", end=True),
]),
"nadia_intro": dict(lines=[
    L("Nadia", "Shop is open. Shop is always open. There is nobody else to open it.", "nadia"),
    L("Kip", "Quiet block.", "kip"),
    L("Nadia", "It was not. Then the Commuters started riding the line down here and stopping.", "nadia"),
    L("Kip", "Stopping is what trains do.", "kip"),
    L("Nadia", "These ones stop and never get back on. Six of them, sat on my wall, every day.", "nadia",
      set_flag="met_nadia", start_quest="q_commuters", shop="nadia_store", end=True),
]),
"nadia_shop": dict(lines=[
    L("Nadia", "Stew is on. It is always on. That is the trick.", "nadia", shop="nadia_store", end=True),
]),
"nadia_done": dict(lines=[
    L("Nadia", "My wall is empty. I could cry.", "nadia"),
    L("Kip", "They will come back.", "kip"),
    L("Nadia", "Then I will feed them. That is how it worked before.", "nadia", end=True),
]),
"bex_intro": dict(lines=[
    L("Bex", "Stop there. Look at your feet.", "bex"),
    L("Kip", "What about them?", "kip"),
    L("Bex", "Those are a street fighter's feet. Wide. Room to swing.", "bex"),
    L("Bex", "Down here there is no room. There is a platform, a wall, and a drop.", "bex"),
    L("Kip", "So I fight smaller.", "kip"),
    L("Bex", "You fight closer. Come back when you can afford to learn the difference.", "bex",
      set_flag="met_bex", shop="bex_dojo", end=True),
]),
"bex_shop": dict(lines=[
    L("Bex", "Feet closer together. Then we begin.", "bex", shop="bex_dojo", end=True),
]),
"roof_kid_intro": dict(lines=[
    L("Kid", "You came up the fire escape. Nobody comes up the fire escape.", "roof_kid"),
    L("Kip", "Where does it go?", "kip"),
    L("Kid", "Everywhere. You can reach Bellwater without touching a single pavement.", "roof_kid"),
    L("Kip", "Why would I want that?", "kip"),
    L("Kid", "Because the Commuters watch the street, and nobody watches up here.", "roof_kid",
      start_quest="q_roof", end=True),
]),
"roof_kid_done": dict(lines=[
    L("Kid", "Told you.", "roof_kid"),
    L("Kip", "You did.", "kip"),
    L("Kid", "I am going to be insufferable about this.", "roof_kid", end=True),
]),
"train_guard_line": dict(lines=[
    L("Guard", "Service is suspended.", "train_guard"),
    L("Kip", "A train just went through.", "kip"),
    L("Guard", "That one does not stop. That one has never stopped.", "train_guard"),
    L("Kip", "Since when?", "kip"),
    L("Guard", "Since they told me to write SUSPENDED on the board. I have a nice hand for it.", "train_guard", end=True),
]),
"bellwater_local": dict(lines=[
    L("Local", "You are the one clearing the wall outside Nadia's.", "performer"),
    L("Kip", "Word travels.", "kip"),
    L("Local", "There are forty of us and one shop. Word sprints.", "performer", end=True),
]),
"metro_poster": dict(lines=[
    L("", "A service poster, laminated and immaculate, on a wall nobody reads."),
    L("", "TUESDAYS: NO STOPPING SERVICE. THIS IS NORMAL AND CORRECT."),
    L("Kip", "Somebody laminated that.", "kip", end=True),
]),
# ---------------- Chapter two: the Line Office ----------------
"office_locked": dict(lines=[
    L("", "A door marked LINE OFFICE. The handle turns; the door does not."),
    L("Kip", "Later, then.", "kip", end=True),
]),
"manager_meet": dict(lines=[
    L("Manager", "You are not the cleaner.", "line_manager"),
    L("Kip", "No.", "kip"),
    L("Manager", "Then you will have to come back. I only see the cleaner.", "line_manager"),
    L("Kip", "Somebody on this line is paying four gangs to sit still.", "kip"),
    L("Manager", "Five.", "line_manager"),
    L("Kip", "...five.", "kip"),
    L("Manager", "The Bellwater lot were added in March. There was room in the line.", "line_manager", end=True),
]),
"manager_reveal": dict(lines=[
    L("Kip", "Who tells you to do it?", "kip"),
    L("Manager", "Nobody tells me. The form arrives. I sign the form.", "line_manager"),
    L("Kip", "What form?", "kip"),
    L("Manager", "Community liaison. Line 4. It has arrived every Tuesday for eleven years.", "line_manager"),
    L("Kip", "Line 4 is closed.", "kip"),
    L("Manager", "Line 4 is *suspended*. Nobody has ever closed it. A closed line is a decision "
                 "and a decision needs a name on it.", "line_manager"),
    L("Kip", "So it still gets money.", "kip"),
    L("Manager", "It still gets a budget. A budget has to be spent or it is reduced, and a "
                 "reduced budget is somebody noticing.", "line_manager"),
    L("Kip", "And the money goes to gangs.", "kip"),
    L("Manager", "The money goes to community liaison. Quiet streets. No complaints about a "
                 "line that does not run. It has worked perfectly.", "line_manager"),
    L("Kip", "You paid people to hurt each other so nobody would ask a question.", "kip"),
    L("Manager", "I paid people to be quiet. What they did with quiet was their own business.", "line_manager", end=True),
]),
"manager_end": dict(lines=[
    L("Kip", "So who do I hit?", "kip"),
    L("Manager", "That is the difficulty, isn't it.", "line_manager"),
    L("", "He turns the form around so Kip can see it. There is no name at the top. There is "
          "a box for one, and it is empty, and it has been empty for eleven years."),
    L("Manager", "You could hit me. I would be replaced by the person who signs when I am on "
                 "leave, and the forms would continue.", "line_manager"),
    L("Kip", "Then stop signing.", "kip"),
    L("Manager", "And then what arrives on Tuesday? Nothing. And then Bellwater has nothing "
                 "either, and Nadia's is shut inside a month.", "line_manager"),
    L("Kip", "...", "kip"),
    L("Manager", "I am not asking you to approve. I am telling you it is load-bearing.", "line_manager",
      set_flag="chapter_2_done", end=True),
]),
"manager_after": dict(lines=[
    L("Manager", "Tuesday again shortly.", "line_manager"),
    L("Kip", "I know.", "kip"),
    L("Manager", "You could take the form. I would not stop you. I would simply be unable to "
                 "tell anyone where it went.", "line_manager", end=True),
]),
"dez_chapter_two": dict(lines=[
    L("Kip", "It is a form.", "kip"),
    L("Dez", "A form.", "dez"),
    L("Kip", "A line that was never closed, a budget that has to be spent, and a man who signs "
             "it because it arrives.", "kip"),
    L("Dez", "So there is nobody to hit.", "dez"),
    L("Kip", "There is nobody to hit.", "kip"),
    L("Dez", "Kip. That is so much worse.", "dez", set_flag="told_dez_ch2", end=True),
]),
}

# ===========================================================================
# ENCOUNTERS
# ===========================================================================
def encounter(id, gang, waves, **kw):
    p = dict(id=id, gang=gang, waves=waves, max_active=4,
             difficulty_scale_per_level=0.06, lock_camera=True, once_flag="",
             respawn_on_reenter=True, boss_id="", reward_flag="", music="",
             intro_dialogue="", clear_dialogue="")
    p.update(kw)
    return p

def wave(enemy_id, count=1, side="any", delay=0.0, boss=False):
    return {"enemy": enemy_id, "count": count, "side": side, "delay": delay, "boss": boss}

ENCOUNTERS = [
    encounter("ferry_tutorial", "pigeons", [wave("pigeon_grunt", 1, "right")],
              max_active=1, once_flag="enc_ferry_tutorial"),
    encounter("ferry_pair", "pigeons", [wave("pigeon_grunt", 2, "any"), wave("pigeon_rusher", 1, "right", 0.5)],
              max_active=3),
    encounter("ferry_squad", "pigeons", [wave("pigeon_grunt", 3), wave("pigeon_rusher", 2, "any", 0.4)],
              max_active=4, reward_flag="ferry_cleared"),
    encounter("market_shakedown", "sweaters", [wave("sweater_grunt", 3), wave("sweater_grappler", 1, "right", 0.6)],
              max_active=4, music="market", reward_flag="market_cleared"),
    encounter("market_optional", "sweaters", [wave("sweater_grunt", 2), wave("pigeon_rusher", 2, "any", 0.3)],
              max_active=3),
    encounter("alley_ambush", "grease", [wave("grease_grunt", 2), wave("grease_weapon", 2, "any", 0.5)],
              max_active=4, music="alley"),
    encounter("alley_boss_fight", "grease", [wave("grease_weapon", 2), wave("grease_grunt", 2, "any", 0.4),
                                             wave("sweater_grappler", 1, "right", 0.8)],
              max_active=4, music="alley", reward_flag="alley_cleared",
              clear_dialogue="alley_note"),
    encounter("yard_wave_1", "rust_rats", [wave("rust_ranged", 2), wave("grease_grunt", 2, "any", 0.4)],
              max_active=4, music="industrial"),
    encounter("yard_wave_2", "rust_rats", [wave("rust_heavy", 1, "right"), wave("rust_ranged", 2, "any", 0.5),
                                           wave("grease_weapon", 2, "any", 0.7)],
              max_active=4, music="industrial", reward_flag="yard_cleared"),
    encounter("hideout_guards", "cleaners", [wave("cleaner_elite", 2), wave("cleaner_grappler", 1, "right", 0.6)],
              max_active=3, music="industrial"),
    encounter("hideout_elites", "cleaners", [wave("cleaner_elite", 2), wave("cleaner_grappler", 2, "any", 0.5),
                                             wave("rust_heavy", 1, "left", 0.8)],
              max_active=4, music="industrial", reward_flag="hideout_cleared"),
    encounter("metro_platform_1", "commuters", [wave("commuter_grunt", 2), wave("commuter_rusher", 1, "any", 0.4)],
              max_active=3, music="metro"),
    encounter("metro_platform_2", "commuters", [wave("commuter_grunt", 2), wave("commuter_ranged", 2, "any", 0.4),
                                                wave("commuter_grappler", 1, "right", 0.7)],
              max_active=4, music="metro", reward_flag="metro_cleared"),
    encounter("rooftop_ambush", "commuters", [wave("commuter_rusher", 3), wave("commuter_ranged", 1, "any", 0.5)],
              max_active=3, music="metro"),
    encounter("bellwater_wall", "commuters", [wave("commuter_grunt", 3), wave("commuter_grappler", 1, "any", 0.5)],
              max_active=4, music="metro"),
    encounter("bellwater_conductor", "commuters", [wave("commuter_heavy", 1, "right"), wave("commuter_grunt", 2, "any", 0.5),
                                                   wave("commuter_ranged", 1, "left", 0.8)],
              max_active=4, music="metro", reward_flag="bellwater_cleared",
              clear_dialogue="metro_poster"),
    encounter("boss_starch", "cleaners", [wave("big_starch", 1, "right", 0.0, True)],
              max_active=1, boss_id="big_starch", music="boss",
              intro_dialogue="starch_intro", once_flag="enc_boss_starch"),
]

# ===========================================================================
# AREA METADATA
# ===========================================================================
AREAS = [
    dict(id="ferry_row", display_name="Ferry Row", district="Riverbend East", music="street",
         ambience="river", gang="pigeons", map_position=(0.0, 0.0),
         connections=["lantern_market"],
         description="Where the river meets the city. Fried dough, ferry horns, and a gang named after birds."),
    dict(id="lantern_market", display_name="Lantern Market", district="Riverbend East", music="market",
         ambience="city", gang="sweaters", map_position=(1.0, 0.0),
         connections=["ferry_row", "grease_alley", "metro_platform"],
         description="Two blocks of food stalls, secondhand books and a dojo nobody can find twice."),
    dict(id="grease_alley", display_name="Grease Alley", district="Backstreets", music="alley",
         ambience="alley", gang="grease", map_position=(2.0, 0.5),
         connections=["lantern_market", "rustpile_yard", "rooftop_route"],
         description="Narrow, damp, full of useful objects and people who resent you finding them."),
    dict(id="rustpile_yard", display_name="Rustpile Yard", district="Industrial", music="industrial",
         ambience="industrial", gang="rust_rats", map_position=(3.0, 0.5),
         connections=["grease_alley", "starch_laundromat"],
         description="A scrapyard nobody is scrapping. The fence is new. That is the strange part."),
    dict(id="starch_laundromat", display_name="Starch & Sons", district="Industrial", music="boss",
         ambience="interior", gang="cleaners", map_position=(4.0, 0.5),
         connections=["rustpile_yard"],
         description="Always open. Always empty. Always immaculate."),
    dict(id="metro_platform", display_name="Metro Platform", district="Metro Line", music="metro",
         ambience="interior", gang="commuters", map_position=(1.0, 1.2),
         connections=["lantern_market", "bellwater_block", "line_office"],
         description="A station that is always open, never busy, and mopped by somebody."),
    dict(id="rooftop_route", display_name="Rooftop Route", district="Above Riverbend", music="market",
         ambience="city", gang="commuters", map_position=(2.6, -0.8),
         connections=["grease_alley", "bellwater_block"],
         description="Aerials, vents and washing lines. Nobody watches up here."),
    dict(id="bellwater_block", display_name="Bellwater Block", district="Metro Line", music="metro",
         ambience="city", gang="commuters", map_position=(2.0, 1.6),
         connections=["metro_platform", "rooftop_route"],
         description="Forty flats and one shop. The Commuters sit on the wall outside it."),
    dict(id="line_office", display_name="Line Office", district="Metro Line", music="shop",
         ambience="interior", gang="", map_position=(0.6, 1.8),
         connections=["metro_platform"],
         description="A desk, four filing cabinets, and eleven years of Tuesdays."),
]

# ===========================================================================
def main():
    for m in MOVES:
        write_tres("moves", m["id"], "MoveData", m)
    print("moves: %d" % len(MOVES))
    for e in ENEMIES:
        write_tres("enemies", e["id"], "EnemyData", e)
    print("enemies: %d" % len(ENEMIES))
    for f in FOODS:
        write_tres("food", f["id"], "FoodData", f)
    print("food: %d" % len(FOODS))
    for b in BOOKS:
        write_tres("books", b["id"], "BookData", b)
    print("books: %d" % len(BOOKS))
    for i in ITEMS:
        write_tres("items", i["id"], "ItemData", i)
    print("items: %d" % len(ITEMS))
    for w in WEAPONS:
        write_tres("weapons", w["id"], "WeaponData", w)
    print("weapons: %d" % len(WEAPONS))
    for s in SHOPS:
        write_tres("shops", s["id"], "ShopData", s)
    print("shops: %d" % len(SHOPS))
    for q in QUESTS:
        write_tres("quests", q["id"], "QuestData", q)
    print("quests: %d" % len(QUESTS))
    for did, d in DIALOGUES.items():
        props = dict(id=did, lines=d["lines"], pause_game=d.get("pause_game", True),
                     once_flag=d.get("once_flag", ""))
        write_tres("dialogue", did, "DialogueData", props)
    print("dialogue: %d" % len(DIALOGUES))
    for e in ENCOUNTERS:
        write_tres("encounters", e["id"], "EncounterData", e)
    print("encounters: %d" % len(ENCOUNTERS))
    for a in AREAS:
        write_tres("areas", a["id"], "AreaData", a)
    print("areas: %d" % len(AREAS))

if __name__ == "__main__":
    main()

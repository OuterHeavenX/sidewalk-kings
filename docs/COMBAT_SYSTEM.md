# Combat system

Combat is the part the rest of the game hangs off, so it is data-driven end to end. Every
attack in the game, for the player and for enemies, is a `MoveData` resource in
`data/moves/`.

---

## A move

`MoveData` (see `combat/MoveData.gd`) carries:

**Timing**, in frames at 60 fps
- `startup` — wind-up before the hitbox exists
- `active` — frames the hitbox can connect
- `recovery` — frames before you can act again
- `cancel_window` — frames after a hit lands during which a follow-up is accepted
- `hitstun` — frames of stun applied to the target

**Damage and physics**
- `damage`, `knockback`, `launch_force`, `knockdown`
- `energy_cost`, `special_cost`
- `forward_move` — how far the attacker slides in during startup
- `self_launch` — vertical launch for the attacker (flying knee)
- `armor` — the attacker shrugs off light hitstun during the move
- `grab_target` — the move initiates a grab on hit

**Hitbox**
- `hitbox_offset.x` — forward reach from the attacker
- `hitbox_offset.y` — strike height, screen-space (negative is up)
- `hitbox_size.x` — width, `hitbox_size.y` — vertical slack
- `lane_tolerance` — half-depth in the lane

**Feel**
- `sound`, `hit_sound`, `hit_fx`, `screen_shake`, `hit_pause`

**Chaining**
- `followups` — move ids reachable from this move

**Unlocking**
- `price`, `required_level`, `required_stat`, `required_stat_value`, `required_move`,
  `required_flag`, `learnable`

---

## The frame loop

`CombatController` runs one move at a time:

```
phase 1  startup   frame >= startup   → activate hitbox
phase 2  active    frame >= active    → deactivate hitbox
phase 3  recovery  if the move hit and frame <= cancel_window → cancel is allowed
                   frame >= recovery  → move ends, actor returns to idle
```

An input during recovery is only honoured if the move connected. Whiffing commits you to
the full recovery, which is what makes heavy attacks a real decision.

Inputs arriving too early are buffered for nine frames, so a slightly rushed combo still
comes out.

---

## Hit detection

The world is a shallow 2.5D lane, so a hit is two separate tests.

**In the lane plane.** The hitbox is an `Area2D` rectangle: `hitbox_size.x` wide along the
street, `lane_tolerance * 2` deep into the lane.

**In height.** Done in code. The strike lands at

```
strike_z = -hitbox_offset.y + attacker.z_height
```

and the target occupies a body span from its feet to roughly 44 px above them. The hit
counts if the strike falls inside that span, widened by `hitbox_size.y * 0.5` of slack.

That is what makes the vertical game work:

- A grounded punch lands at chest height and catches anyone standing.
- Jumping high enough takes your body above a grounded attack's slack, so you dodge it.
- A jump kick aimed below the attacker still catches a target on the ground.
- Attacking from very high up misses entirely.

Hitboxes keep `monitoring` enabled permanently and gate on an `active` flag. Enabling
`monitoring` per swing costs a physics frame, which is long enough for a three-frame jab to
miss every time.

Each move records the instance ids it has already hit, so a single swing cannot hit the
same target twice, and `multi_hit` sweeps like the spin kick still reach several enemies.

---

## The combo chain

The player's core chain is defined entirely in data:

```
punch_1 (Jab)        → punch_2, heavy, uppercut
punch_2 (Cross)      → punch_3, heavy, kick, uppercut
punch_3 (Body Hook)  → heavy, kick, spin_kick
kick   (Roundhouse)  → heavy
```

A follow-up must (a) be listed in `followups`, (b) match the input kind pressed, and
(c) be a move the player has actually learned. The last condition is why buying a technique
at the dojo immediately changes how the basic chain flows.

Beyond the chain there are:

| Move | How it comes out |
|---|---|
| Jump Kick | Light while airborne |
| Falling Stomp | Heavy while airborne (learned) |
| Shoulder Charge | Light while running |
| Flying Knee | Heavy while running (learned) |
| Grab | U next to a fighter |
| Held Knee | Light while grabbing |
| Throw | Heavy or jump while grabbing |
| Ground Stomp | Heavy over a downed enemy |
| Weapon Swing | Light while carrying |
| Weapon Throw | Heavy while carrying |
| Sidewalk Special | I, at a full special meter |

---

## Damage

```
final = move.damage
      × attacker multiplier (by damage kind)
      × crit (1.6× on a roll against crit chance)
      − target defence
```

Player multipliers come from `PlayerState`: punch, kick, throw, weapon and special each
scale from a different mix of Strength, Technique and their permanent bonuses. Incoming
damage is reduced by `100 / (100 + defense × 4)`, which keeps Defence useful without ever
reaching immunity.

Heavy enemies have an `armor_threshold`: any hit below it does damage but does not stagger
them, so you cannot jab a Girder into submission.

---

## Reactions

A hit resolves into one of three outcomes:

- **Absorbed** — damage below an armored target's threshold. Damage lands, no stagger.
- **Hit stun** — `hitstun` frames of the hurt state, plus knockback scaled by weight.
- **Knockdown** — the target is launched, falls, lies on the ground for about three
  quarters of a second, then gets up with brief invulnerability.

Knockback is divided by the target's `weight`, so the same punch shoves a Skimmer across
the pavement and barely moves a Girder.

---

## Grabs and throws

`U` next to a fighter grabs them if they are grabbable and roughly level with you. While
holding:

- **Light** works them over. Three hits and they slip free.
- **Heavy** or **jump** throws them.

A thrown body stays dangerous for forty frames: anyone it crashes into is knocked down too.

Bosses cannot be grabbed in phase one. Big Starch only becomes grabbable once he drops
below half health, which turns the phase change into an opening rather than just a
difficulty bump.

---

## Feel

Every impact fires several things at once, all configured on the move:

- **Hit pause** freezes the game briefly. Light hits use 35 ms, heavies 85 ms, the
  special 120 ms.
- **Screen shake** adds camera trauma that decays; the camera squares the trauma so small
  hits stay subtle.
- **Impact sparks** spawn at the contact point, sized to the attack.
- **A flash** whitens the target for two frames.
- **Layered sound**: the swing whoosh, then the impact.
- **Floating numbers** in yellow, or larger and orange on a crit.
- **Slow motion** on the boss's phase change and defeat.

The special and the boss defeat also use `EventBus.slow_motion`, which scales
`Engine.time_scale` while leaving UI animation alone.

---

## Defence

Two answers to an incoming attack, both paid for in energy.

### Guard

Hold the sprint input while standing still. The same input runs when you are moving, so it
reads as "commit" and your direction decides to what.

| | |
|---|---|
| Absorbs | Ordinary attacks, for chip damage of about a quarter |
| Breaks against | Heavy attacks and anything that knocks down |
| Costs | Energy while held, plus a chunk per hit absorbed |
| Blocks you from | Moving, attacking, grabbing |
| Unavailable | At empty energy, or in the air |

`Actor.take_damage` checks `is_guarding()` before anything else, and `_guard_absorbs()`
decides whether the hit gets through. Enemies inherit the same hooks but do not guard yet,
which is where a shielder archetype would slot in.

### Dodge roll

Double-tap a direction. Reuses the double-tap detection that was scaffolded in `Player.gd`
from the start.

| | |
|---|---|
| Invulnerable | Most of the roll, not all of it |
| Travels | A fixed distance at roll speed, driven by `roll_dir` rather than live input |
| Costs | Energy |
| Follow-up | **Dash Strike** is available in a short window after the roll |

The follow-up is the point. Dash Strike stops being a standalone lunge and becomes the
aggressive answer to a well-read roll, which gives the dojo purchase a real identity.

## Crowds

A group of enemies is coordinated by `EnemyDirector`, not left to each enemy deciding
alone. Every 0.6s it hands out roles and approach sides.

| Role | Behaviour |
|---|---|
| **Attacker** | May commit to an attack. Only two at a time. |
| **Flanker** | Walks around the player to its assigned side. Will not attack on the way. |
| **Waiting** | Holds at a distance, circling. |

Each enemy also carries a **desired side**, left or right of the player. The director keeps
the split even, so a crowd surrounds you instead of queuing up on whichever side it spawned.

Two details make this work rather than thrash:

**Sides are sticky.** Recomputing them from current positions every cycle sent an enemy
that was halfway around the player straight back again, because crossing over made it the
nearest one. It paced on the spot forever. Sides now persist, and only rebalance when the
split is genuinely lopsided, moving whoever is furthest from the player.

**Enemies are not solid to each other, or to the player.** Hard bodies made a crowd jam: a
flanker walking round would shoulder into whoever was already engaging and stall against
them. Enemies now sit on their own collision layer and collide only with solid props.
Overlap is resolved by pushing apart softly each frame, which is how a brawler crowd should
behave anyway.

A flanker also swings out to the near edge of the lane before travelling along it, rather
than pushing straight through the fight. There is no pathfinding, so a flanker can still
meet a solid prop; if it stops making progress while trying to move it flips to the other
edge of the lane and tries again.

## Telegraphs

Guard and dodge are only fair if the attacks worth answering can be read coming. `MoveData`
carries a `telegraph` flag; heavy and slam attacks set it.

A telegraphed move pulses a warning colour for its whole startup and plays a short audio
cue, so a tell off the edge of the screen is still fair. The startup is long enough to
react to: nothing marked as telegraphed comes out in under about a fifth of a second, and
the test suite asserts that.

## Energy and the special meter

- **Energy** gates heavy and technique moves and refills continuously, faster with
  Stamina and the stamina-recovery bonus. Spending it pauses regeneration briefly, so
  spamming heavies is self-limiting.
- **The special meter** fills only through combat: landing hits, and taking them. At 100 it
  powers one Sidewalk Special, which hits everything nearby, launches it, and gives brief
  invulnerability on start-up.

---

## Adding a move

1. Add an entry to `MOVES` in `tools/gen_data.py`.
2. If it should be purchasable, set `learnable`, `price` and any requirements, then add its
   id to a dojo or book in the same file.
3. If it should chain, add its id to another move's `followups`.
4. Run `python tools/gen_data.py`.
5. Run the smoke test. It verifies that every move id referenced anywhere resolves.

No engine code changes.

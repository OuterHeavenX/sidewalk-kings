# Architecture

How the code is organised and why. The guiding rule is that **content is data and systems
are code**, so a new neighbourhood, enemy, weapon or shop is a new file in `data/`, not a
new script.

---

## Layers

```
          ┌──────────────────────────────────────────────┐
          │  Autoloads (always alive)                    │
          │  EventBus  GameManager  SaveManager          │
          │  SceneManager  AudioManager  InputManager    │
          │  ContentDB  QuestManager  DialogueManager    │
          │  ShopManager                                 │
          └───────────────┬──────────────────────────────┘
                          │ signals + direct calls
          ┌───────────────▼──────────────────────────────┐
          │  Game (scenes/game/Game.tscn)                │
          │  owns the camera, the current Area, the      │
          │  player, the HUD, pause menu, touch controls │
          └───────────────┬──────────────────────────────┘
                          │
          ┌───────────────▼──────────────────────────────┐
          │  Area (built at runtime from JSON)           │
          │  parallax · ground · scenery · props · NPCs  │
          │  doors · weapons · spawns · triggers         │
          │  owns an EnemyDirector                       │
          └───────────────┬──────────────────────────────┘
                          │
          ┌───────────────▼──────────────────────────────┐
          │  Actors: Player, EnemyBase, Boss             │
          │  each with a CombatController + Hitbox       │
          └──────────────────────────────────────────────┘
```

Nothing below the autoload layer reaches upward by node path. Systems talk through
`EventBus` signals or through the autoload singletons.

---

## The autoloads

| Autoload | Responsibility |
|---|---|
| `EventBus` | Signal hub. Declares every cross-system signal and owns no state. |
| `GameManager` | Game state machine, the `PlayerState` instance, money/XP/flags/items, and time effects (hit stop, slow motion). |
| `SaveManager` | Versioned JSON save/load and settings persistence. |
| `SceneManager` | Boot → title → game flow, area transitions, the fade overlay. |
| `AudioManager` | Buses, pooled SFX players, music cross-fade, ambience. |
| `InputManager` | Registers every input action in code; tracks whether touch is in use. |
| `ContentDB` | Loads every resource under `data/**` at startup and serves it by id. |
| `QuestManager` | Quest state, objective tracking, turn-ins. |
| `DialogueManager` | Interprets `DialogueData` and drives the dialogue box. |
| `ShopManager` | Builds shop entries and applies purchases for every shop type. |

`PlayerState` is a plain `RefCounted` holding all persistent player data with
`to_dict()` / `from_dict()`. Keeping it out of the node tree is what makes saving,
loading and resetting a single assignment.

---

## The 2.5D coordinate system

The game is a side-scroller with depth, so coordinates carry a specific meaning:

- **`position.x`** runs along the street.
- **`position.y`** is depth *into* the lane. Smaller y is further away. Because
  `Actors` has `y_sort_enabled`, this also sorts characters back-to-front for free.
- **`z_height`** is how far a character is off the ground. Gravity applies only here.

`Visual.position.y = -z_height` lifts the sprite while the shadow stays on the ground.

Attacks therefore have to test two things:

1. **The lane plane** — an `Area2D` rectangle covering x (reach) and y (lane tolerance).
2. **Height** — done in code, comparing the strike height against the target's body span.

Splitting them is what makes jumping over a low attack work, and what lets a jump attack
aimed downward still catch someone standing on the ground.

---

## Combat

```
input → Player._press_attack → MoveData → CombatController.start_move
        → startup frames → Hitbox.activate → active frames
        → Hurtbox.apply(DamageData) → Actor.take_damage
        → recovery frames, with a cancel window if the hit landed
```

- **`MoveData`** is a resource: timing in 60 fps frames, damage, knockback, hitbox shape,
  costs, sounds, screen shake, hit pause, and the ids of moves it can chain into.
- **`CombatController`** is generic. It drives any `Actor` and knows nothing about who owns
  it, so the player, grunts and the boss all use the same code path.
- **`DamageData`** is one instance of damage in flight, built from a `MoveData` plus the
  attacker's multipliers.
- **Combos** are data: `MoveData.followups` lists move ids, and a follow-up is only
  reachable inside the cancel window that opens when a hit connects.

Because moves are resources, a new technique is a new `.tres` file plus an entry in a dojo
or book. No code changes.

---

## Enemies

`EnemyBase` is the only enemy script. An `EnemyData` resource supplies stats, archetype,
sprite frames, AI parameters, move ids and drops.

The AI is a small state machine (`WAIT`, `APPROACH`, `CIRCLE`, `RETREAT`, `ATTACK`,
`SEEK_WEAPON`) with a preferred fighting distance, a reaction delay, an attack cooldown and
a circling chance. Enemies also push apart from one another each frame, so a group spreads
out rather than stacking on one pixel.

`Boss` extends `EnemyBase` and adds an intro, a telegraphed heavy attack with a visible
wind-up, and a second phase below half health that raises speed and aggression and finally
allows the boss to be grabbed.

`EnemyDirector` owns encounters. It reads an `EncounterData` resource, spawns waves from
off-screen up to a cap, sends reinforcements as the crowd thins, locks the camera for the
duration, and reports when the fight is clear. Spawn data never lives in enemy code.

---

## Areas

An `Area` is built at runtime from `data/areas/<id>.json`. The layout describes parallax
layers, ground tile strips, scenery sprites, props, weapons, NPCs, doors, spawn points and
encounter triggers. `Area.gd` interprets it; there is no per-area scene or script.

This is the main lever for cheap expansion: a new neighbourhood is one JSON layout, one
`AreaData` resource, and whatever new content it references.

The vertical bands of a street are documented in `tools/gen_areas.py`.

---

## UI

The HUD, pause menu, shop and dialogue box are built in code rather than laid out in
scenes. At a 480×270 design resolution, code-built layout is easier to keep consistent, and
`UITheme` centralises the palette and widget styling.

`ShopController` handles every shop type from `ShopData`, so the restaurant, store, dojo,
bookstore and weapon shop are one scene and one script.

---

## Time effects

`GameManager` owns hit stop and slow motion by driving `Engine.time_scale`. Anything that
must keep running during them (screen fades, tweens on menus) explicitly ignores time
scale. `Actor._physics_process` returns early while frozen, which is what gives a heavy hit
its pause without stopping the UI.

---

## Deliberate choices

- **Scenes are generated** (`tools/gen_scenes.py`) so node paths, collision layers and
  script bindings stay consistent and reviewable as text.
- **Hitboxes keep `monitoring` on** and gate on an `active` flag instead. Toggling
  `monitoring` per swing costs a physics frame, which is long enough for a three-frame jab
  to miss entirely.
- **The screen fade is stepped by hand**, not tweened. The fade gates scene flow, and a
  tween that fails to finish would trap the player behind a black rectangle.
- **`CharacterBody2D` with floating motion mode**, not gravity. Vertical movement is lane
  depth, and jumping is handled separately in `z_height`.

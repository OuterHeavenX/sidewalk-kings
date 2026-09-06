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
| `Renderer2D` | Owns the single `WorldEnvironment` and its bloom settings, and keeps HDR 2D on. |
| `CutsceneManager` | Runs scripted scenes from `data/cutscenes/*.json`: camera, blocking, dialogue, flags. |

### Two audio rules that must not be broken

Both of these silence the game with no error of any kind, and both have shipped:

- **Never create audio buses at runtime.** `AudioServer.add_bus()` silences a web export
  completely. Buses come from `default_bus_layout.tres`, which loads before the audio
  driver starts. `AudioManager` verifies them and never creates them.
- **Never fade audio with a `Tween`.** A tween that does not advance leaves the volume at
  its starting value, and for music that value was -40 dB, which reads as a hum rather
  than as a bug. Fades are stepped in `_process`, like `SceneManager`'s screen fade. A
  track with nothing to cross-fade from starts at full volume, so a stalled fade can only
  cost a transition.

The smoke suite asserts both against the source, because a headless run uses the Dummy
audio driver and cannot hear anything. `AudioCheck`, run with a real driver, asserts that
signal actually reaches the Master bus.

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

### Cutscenes

A cutscene is a list of steps in `data/cutscenes/<id>.json`. `CutsceneManager` sets the
game state to `CUTSCENE`, which is all that is needed to stop the player, the enemy
director and the encounter triggers, because each of them already gates on the game being
in `PLAYING`.

Two rules, both learned the hard way:

- **Story-critical flags go on a cutscene step, never only inside its dialogue.** A player
  who skips the scene skips the dialogue with it. `abort()` applies every remaining flag
  and quest step before returning for exactly this reason, but that only helps if the
  content puts the flag on a step. A skipped scene that leaves a chapter unfinishable is
  the worst failure this system can have, and it is silent.
- **Scripted camera is separate from `lock_to`.** Locking clamps the camera that is
  following the player; scripting replaces the follow entirely. Conflating them means a
  cutscene pan fights the player's position.

### Ambient motion

A layout may carry `sway` and `flicker` flags on individual scenery items, plus an
area-level `ambient` block for wind-blown litter. One `Ambient` node per area drives every
effect from a single `_process`, rather than giving each swaying awning its own script: a
street has a couple of dozen of these and they are all doing arithmetic on one float.

None of it affects gameplay. No collision, no damage, no state.

Two rules that are not obvious:

- **Everything moves in whole pixels.** The project snaps 2D transforms to the pixel grid,
  so a sub-pixel sway judders between two positions at an uneven rate rather than moving
  smoothly. One or two pixels at a slow rate reads as a breeze; anything finer reads as a
  fault.
- **Flicker changes `modulate` on the scenery sprite, not on its emission overlay.**
  Modulate is inherited by children, so the overlay from the lighting pass rides along and
  the bloom pulses with the light rather than staying at a constant glow behind a
  flickering lamp.

### Lighting

A layout may carry an optional `lighting` block. `AreaLighting` reads it and builds a
`CanvasModulate` for the ambient tint plus a `PointLight2D` per declared pool. An area
without the block builds nothing and renders exactly as it did before lighting existed,
which is what lets it roll out one street at a time.

`Emission` attaches glow overlays. A sprite whose asset has a mask under
`assets/art/emission/` gets a second sprite on top of it, holding only the emissive pixels
at a gain above 1.0. With HDR 2D on and the bloom threshold at 1.0, ordinary art clamps
and cannot bloom, so only those overlays do.

Two coupling rules matter and are both asserted in the smoke suite:

- Lighting is built **before** props, because it computes the ambient compensation that
  the overlays need. A dark area multiplies emission down along with everything else, so
  without compensation a lamp stops blooming exactly when the scene gets dark enough to
  need it.
- Overlays only attach when the area is actually lit. Attached anywhere else they render
  at raw gain, clamp to white, and blow the asset out.

---

## UI

The HUD, pause menu, shop and dialogue box are built in code rather than laid out in
scenes. At a 480×270 design resolution, code-built layout is easier to keep consistent, and
`UITheme` centralises the palette and widget styling.

`ShopController` handles every shop type from `ShopData`, so the restaurant, store, dojo,
bookstore and weapon shop are one scene and one script.

### Builds identify themselves, and update themselves

`GameManager.version` comes from the project settings and only changes when somebody
remembers to change it. `GameManager.build` comes from `data/build.json`, written by
`tools/stamp_build.py` in CI, and changes every build. The second is the one that answers
"is this the update?", so `version_line()` shows both and it is not hidden behind a debug
flag.

Two rules learned by getting them wrong:

- **The stamp must be a file type the export includes.** The preset includes `*.json` and
  excludes `*.txt`. As a `.txt` it was generated, committed, and dropped from the package,
  and the exported game reported `dev` while looking healthy.
- **A cached app cannot be assumed to be a current app.** Godot's service worker handles
  `claim` and `update` messages but sends itself nothing; without a handler in the shell a
  new worker waits forever while the old one serves `index.pck`, which is the whole game.
  `web/shell.html` applies the update immediately if it arrives within a minute of load,
  and otherwise hands it to the next launch, so play is never interrupted.

### Doors have to be visible

A door is a trigger volume with no appearance of its own. Nothing about placing one puts
anything on screen, so a door can be correct in every testable way — graph symmetric,
spawn valid, collision mask right, travel working — and still be undiscoverable. That is
exactly what happened to the route back onto the roofs and to Bex's dojo.

Two rules:

- **Every interactable door needs art that reaches it.** Not near it: scenery is anchored
  top-left, so a check that compares anchor positions will clear a door standing under the
  far end of a 126 px shopfront and flag four that are perfectly visible.
- **The affordance is the art's job, not the prompt's.** The HUD prompt appears within
  26 px, which is close enough to be standing in the doorway. The chevron marker starts at
  108 px, and the fire escape sprite hangs its ladder down within reach so the shape itself
  says climbable.

### Impacts are measured, not eyeballed

A landed hit must carry more energy than the swing that led into it, and that is checked in
`tools/check_audio.py` rather than in the smoke test. Godot imports WAVs as QOA, so
`AudioStreamWAV.data` at runtime is compressed bytes; decoding it as PCM yields noise that
measures about -5 dB for every sound. The sources on disk are PCM, so the check lives with
them.

Judge impacts by RMS. The original hit sounds normalised to a -1.6 dB peak and measured
-25 dB RMS: a click with a tall spike and no body, which playtesting reported as no punch
sound at all.

A move's impact sound comes from its `damage_kind`, not from a per-move argument.

### The map

`MapView` draws nodes from `AreaData.map_position` and edges from `AreaData.connections`.
Neither is authored for the map specifically, which is the point: the map is a view of the
world graph and cannot drift out of agreement with it. Adding an area to `gen_data.py` puts
it on the map with no map work at all.

Whether a place is known is a flag, `visited_<area_id>`, written by `Game.load_area()` on
entry. Two rules follow from how that went wrong the first time:

- **The flag is written by the thing that moves the player, not by the map.** The map only
  reads it. When nothing wrote it, every area read as unvisited and the screen looked
  completely convincing while being completely wrong.
- **The test asserts entering an area writes the flag**, not that the map renders. The map
  rendered fine with the bug present. Testing the observable surface would have passed.

Fast travel is refused while an encounter is live. Leaving a fight through a menu strands
the director running an encounter with no player in it, and would make every fight in the
game optional.

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

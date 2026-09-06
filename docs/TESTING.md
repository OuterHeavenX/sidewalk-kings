# Testing

Two harnesses run the real game with no human at the keyboard: one checks behaviour, the
other captures how it looks.

---

## Automated smoke test

```bash
godot --headless --path . -- --smoke
```

Boots the game, starts a session and drives it through 357 checks. Exit code is 0 if
everything passes, 1 otherwise, so it works in CI. Results print to stdout and are also
flushed line by line to `user://smoke_test.log`, which means a hang or crash still leaves a
record of exactly how far it got.

Implementation: `tests/SmokeTest.gd`, launched from `scenes/boot/Boot.gd` when `--smoke` is
in the user arguments.

### What it covers

| Section | Checks |
|---|---|
| **Content** | Every content type loads. Every cross-reference resolves: move follow-ups, enemy moves, encounter enemies, shop stock, quest rewards, NPC dialogue, door destinations, prop contents, placed weapons. Every area layout exists and parses. |
| **Title flow** | Title screen loads, the screen is not left dimmed, New Game reaches the gameplay scene, the fade completes, the player exists, the opening conversation runs. |
| **New game** | The game scene, player and area all build, with a populated street. |
| **Movement** | Walking, facing, running faster than walking, lane movement, lane clamping, jumping and landing. |
| **Combat** | Light attack damage; the combo chain landing multiple hits **and** advancing through Jab → Cross → Body Hook; heavy attack damage and knockdown; jump attack connecting; grab, grab attack and throw; the special consuming its meter; enemy AI closing distance, starting attacks and actually damaging the player; enemies dying, awarding XP and dropping money. |
| **Weapons** | Given and held, swings damaging, durability decreasing, fragile weapons breaking, throwing. |
| **Pickups and props** | Money collected by walking over it; breakable props opening. |
| **Progression** | XP levelling up, level raising max HP, stats and bonuses raising multipliers, the player syncing new stats. |
| **Shops** | Every shop has stock and sells something; the dojo teaches moves; food heals and grants permanent stats; books are recorded. |
| **Quests and dialogue** | A quest starts, progresses, completes and turns in at its giver; an item quest tracks a pickup; a conversation runs to its end; every dialogue resource is structurally valid. |
| **Travel** | Every area in `ContentDB` loads and builds, and the camera can frame the player at both ends of each. The list is not hand-written, so a new area is covered the day it is added. |
| **Lighting** | The bloom threshold is 1.0 and HDR 2D is on, which is what stops ordinary art blooming. Every emission mask has source art; every light texture a layout names exists. A lit area gets its ambient tint, its lights and its emission overlays, with the gain compensated for the ambient. With the setting off it builds no lights, no bloom and no overlays. An area with no lighting block is untouched. Reloading an area keeps the player where they stood. |
| **World graph** | Every area has a layout; every door lands on a spawn point that exists; every door has a return door; the map screen's connections match the real doors; every area is reachable on foot from Ferry Row. |
| **Chapter two** | The metro gate is shut before the story opens it. Each Metro Line area builds, each spawn puts the player at the correct end of the street, the camera frames them, the locker carrying the quest flag is searchable, and a Commuter takes damage. |
| **Boss** | The intro plays and closes; the boss spawns with boss-scale health; phase one blocks grabs; it enters phase two below half health and becomes grabbable; invulnerability expires; it can be defeated, is recorded, and pays out. |
| **Touch controls** | The overlay appears in touch mode and listens for input; every button is on screen, none overlap, and the cluster stays compact in the bottom-right; tapping the light button attacks; dragging the stick moves the player; the stick keeps working while a button is held; releasing returns it home; a tap on empty screen falls through to the rest of the UI. |
| **Save and load** | Writing, reading a summary, clearing with a new game, restoring level, money, moves, flags, inventory and area, and migrating a pre-versioned save. |

### Notes on how it is written

- **It steps physics frames, not render frames.** Gameplay lives in `_physics_process`, and
  in a headless run render frames are uncapped, so counting them measures nothing.
- **`clear_stage()` resets between checks**: aborts encounters, disarms the street's
  triggers, closes dialogue, frees enemies, and moves loose interactables out of reach.
  Without it, a check teleporting the player starts real fights and opens real
  conversations, and every later check inherits a broken state.
- **Targets are chosen for determinism.** A durability check uses an enemy that survives
  the swing; a combo check uses one that cannot be knocked out mid-chain.

### Bugs this found

Worth recording, because they are the reason the harness exists:

- Camera limits were set as bounds on the camera *centre* rather than world edges, so the
  view could not follow the player to either end of a street.
- Vertical hit detection compared a strike point against the target's feet, making jump
  attacks impossible to land.
- Enemies computed lane distance from an already-relative vector, so they approached and
  then never attacked.
- The HUD notification queue looped forever, because `queue_free()` is deferred and the
  trim loop kept counting the same children.
- An attack pressed immediately after a jump fell through to a grounded move that could not
  start, so it did nothing.
- The screen fade could stall and leave the player behind a black rectangle.
- Touch input was mapped through the screen transform twice, so on a phone no on-screen
  button could be hit and the stick jumped into the corner. This one shipped: the original
  tests only checked that the controls were *visible*, never that a touch reached them.

---

## Screenshot pass

```bash
godot --path . --resolution 1280x720 -- --shots
```

Runs with real rendering and writes PNGs to `user://shots/`: the title screen, the opening
street, a crowd fight, a punch, a heavy, a weapon swing, the HUD, a conversation, the
restaurant, the dojo, three pause pages, the touch controls, every area, and the boss fight.

It is how the visual problems were found: missing background textures, wrong camera
framing, cars and fences drawn behind the road, touch buttons pushed off screen, and a
laundromat floor that read as a transparency checkerboard.

Implementation: `tests/ScreenshotTool.gd`. It clears the output folder first, because shot
numbering shifts between runs and stale files are worse than none.

---

## Browser verification

The committed web build was served over a local static server and played in a Chromium
browser: title screen, New Game, the opening conversation with Dez, movement and combat.

Two things only reproduce in a browser, and both were found this way:

- **A hidden tab throttles the animation loop** and collapses the canvas to zero size, so
  the game appears black. This is browser behaviour, not a bug, but it is easy to
  misdiagnose. The shell now re-syncs the drawing buffer on visibility and viewport
  changes.
- **A zero-size canvas at start-up** hands WebGL an incomplete framebuffer. The canvas is
  now pinned to the viewport rather than laid out by a flex parent.

---

## Manual checklist

Things the automated passes do not cover, to run before a release:

- [ ] Gamepad: movement, all five actions, menu navigation
- [ ] Physical touchscreen device (only emulation has been used so far)
- [ ] Audio sliders in both the title and pause menus, and that they persist
- [ ] Browser refresh mid-game, then Continue from the title
- [ ] Death and respawn, including the money penalty
- [ ] Every door in both directions
- [ ] Buying every dojo technique and confirming each changes the combo chain
- [ ] Weapon breaking mid-combo
- [ ] Window resize and fullscreen during play
- [ ] Portrait orientation on a phone

---

Note that the engine's own touch delivery cannot be exercised in a headless run, so the
touch checks call `TouchControls._input` directly. That covers the hit-testing and stick
maths, which is where the bug was; delivery itself is engine code.

## Running in CI

`.github/workflows/export-web.yml` installs Godot and the export templates, imports the
project, runs the smoke test, exports the web build, and fails if `web/index.html` is
missing or if any check fails.

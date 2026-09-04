# Changelog

All notable changes to Sidewalk Kings. Format based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project uses
[semantic versioning](https://semver.org/).

---

## [0.1.0] — 2026-09-04

First playable vertical slice. Every system the full game needs, proved end to end.

### Added

**Combat**
- Data-driven move system: 39 `MoveData` resources covering the player, enemies and the
  boss, with frame-accurate startup, active and recovery windows
- Three-hit light chain (Jab → Cross → Body Hook) with cancel windows that only open on a
  connected hit, plus heavy and kick branches
- Jump attacks, running attacks, ground stomps, grabs, held attacks and throws
- Thrown bodies knock down whatever they hit
- Seven purchasable techniques: Uppercut, Spin Kick, Dash Strike, Flying Knee, Counter
  Stance, Power Punch, Falling Stomp; plus Back Suplex from a book
- A special meter that fills through combat and powers an area-clearing attack
- Hit stop, camera shake, impact sparks, hit flash, floating damage numbers, layered audio
- Armor on heavy enemies, weight-scaled knockback, crits

**Enemies**
- Six archetypes: grunt, rusher, grappler, weapon user, heavy, ranged
- AI with preferred fighting distance, reaction delay, attack cooldowns, circling, lane
  repositioning and separation, so a crowd surrounds instead of stacking
- `EnemyDirector` running encounters from data: waves, caps, reinforcements, camera lock
- Eleven enemies across five gangs

**Boss**
- Big Starch: two phases, a telegraphed slam with a visible wind-up, a phase-two charge,
  a dedicated health bar, unique music, an intro and a defeat conversation
- Ungrabbable in phase one, grabbable in phase two

**Progression**
- Six stats and nine permanent bonuses
- Levelling, money, XP, physical money drops that bounce onto the street
- Five shop types from one controller: restaurant, store, dojo, bookstore, weapon shop
- 13 foods that heal and permanently raise stats, 8 books that grant bonuses and moves

**World**
- Five connected areas built at runtime from JSON layouts
- Doors, spawn points, positional encounter triggers, flag-locked routes
- Breakable and searchable props that drop money, food and weapons
- 11 environmental weapons with durability, throwing and breaking
- 10+ NPCs with conditional dialogue that changes as the story moves

**Systems**
- Quests: 8, tracking themselves off event signals
- Dialogue: portraits, typewriter text, skipping, choices, and effects on lines
- Versioned JSON saves that work identically on desktop and in the browser
- Audio manager with five buses and persisted volume settings

**Presentation**
- 24 original characters, 1,279 animation frames, 29 animations
- 31 props, 11 weapons, 13 tiles, 11 buildings, five skies, three skylines
- 42 sound effects, 8 music tracks, 5 ambience beds, all synthesised
- HUD, pause menu with six pages, title screen, shop and dialogue UI

**Mobile and web**
- Multitouch controls: a sliding virtual stick and five action buttons, each tracking its
  own touch index
- Safe-area handling for notched devices
- A production web export with a custom loading shell, committed and deployable

**Tooling**
- Six generators producing all art, audio, content and scenes
- `tests/SmokeTest.gd`: 107 automated checks with a non-zero exit on failure
- `tests/ScreenshotTool.gd`: visual capture of every screen
- A debug panel behind F1, disabled in production builds

### Fixed

Bugs caught by the automated harnesses during development, listed because they are why the
harnesses exist:

- Camera limits were set as bounds on the camera centre rather than world edges, so the
  view could not follow the player to either end of a street
- Vertical hit detection compared a strike point against the target's feet, making jump
  attacks impossible to land; it now tests the target's body span, which also makes
  jumping over a low attack work
- Enemies computed lane distance from an already-relative vector, so they approached the
  player and then never attacked
- The HUD notification queue looped forever, because `queue_free()` is deferred and the
  trim loop kept counting the same children
- The screen fade could stall and leave the player behind a black rectangle; it is now
  stepped by hand with a bounded wait
- An attack pressed immediately after a jump fell through to a grounded move that could not
  start, so it did nothing
- Touch controls were positioned using desktop screen-space safe-area insets, which pushed
  them off screen
- Area background and building textures were requested without a `.png` extension, so every
  backdrop silently failed to load
- Cars and fences drew behind the road they stand on
- A three-frame jab could miss entirely, because enabling `Area2D` monitoring per swing
  costs a physics frame
- The web canvas could start at zero size and hand WebGL an incomplete framebuffer

### Known issues

See the [README](../README.md#known-issues).

---

## [0.1.1] — 2026-09-04

### Fixed

- **Touch controls did nothing on a phone.** Touch positions arrive already in viewport
  coordinates, but they were being passed through the screen transform a second time. On a
  device that shrank every tap toward the top-left by the content scale factor, so the
  action buttons could never be hit and the stick jumped into the corner over the HUD.
- **The stick never returned home.** It recentred under the thumb on touch, as intended,
  but stayed wherever it was released, which read as a broken control.
- **Touches were swallowed even when nothing was hit**, so tapping could not advance
  dialogue. Events are now consumed only when a control takes them.
- Holding a touch button no longer suppresses keyboard movement on devices with both.

### Changed

- Action buttons moved from a wide arc to a compact gamepad-style diamond in the corner.
  The arc pushed the top button nearly half way up the screen, out of thumb reach and over
  the game. Spacing is now at least one button width so no two hit areas touch.
- Buttons and the stick are larger (44 px and 50 px at the base scale) and slightly more
  transparent at rest, so the street stays readable underneath.
- Ground now has a solid backing band behind the tiles, and sky layers cover more vertical
  space, so tall and portrait viewports no longer show empty bands above and below.

### Added

- Fifteen automated touch checks: layout on screen, no overlap, a compact cluster in the
  corner, tapping a button attacking, dragging the stick moving the player, moving and
  attacking at once, the stick returning home, and empty taps falling through. The suite is
  now 125 checks.

---

## Unreleased — Phase 2, Stage 1

See [PHASE_2.md](PHASE_2.md) for the full plan.

### Added

- **Guard.** Hold the sprint input while standing still. Absorbs ordinary attacks for chip
  damage, breaks against heavy blows, drains energy while held, and is unavailable on an
  empty bar. The player could previously only answer an attack by outspacing it, jumping,
  or trading, which flattened every fight into the same exchange.
- **Dodge roll** on a double-tap, with invulnerability through most of it and an energy
  cost. **Dash Strike** is now its follow-up, which gives that dojo purchase an identity
  beyond being a standalone lunge.
- A sixth touch button for guard, since the stick already means run. Special and guard now
  flank the action diamond.
- Thirteen automated checks covering guard damage reduction, energy drain, guard break,
  the empty-energy case, roll cost, roll invulnerability, roll travel, and the touch guard
  button. The suite is now 140 checks.

### Decided

- Night lighting will use Godot's built-in 2D lights rather than the `lit` addon. Lit
  requires the Forward+ renderer and does not support Compatibility or Mobile; this game
  runs on Compatibility, which is what makes the browser and mobile builds work at all.

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
- **Enemy flanking.** `EnemyDirector` assigns engagement roles and approach sides so a
  crowd surrounds the player instead of queuing on whichever side it spawned. Only two
  enemies may commit to an attack at once; the rest walk around or hold back.
- **Telegraphed attacks.** `MoveData.telegraph` marks heavy and slam moves. A telegraphed
  move pulses a warning colour through its startup and plays an audio cue.
- Thirteen automated checks covering guard damage reduction, energy drain, guard break,
  the empty-energy case, roll cost, roll invulnerability, roll travel, and the touch guard
  button, plus eight more covering the crowd split, the attacker cap, an enemy actually
  walking around to the far side, and a telegraph's wind-up preceding its hitbox. The suite
  is now 148 checks.

### Changed

- Enemies no longer collide with each other or with the player. Hard bodies made crowds
  jam: a flanker walking round would stall against whoever was already engaging. They now
  sit on their own collision layer, collide only with solid props, and are pushed apart
  softly each frame.
- A flanker that stops making progress, typically against a solid prop, now flips to the
  other edge of the lane rather than pressing into it forever. There is no pathfinding.

### Fixed

- **Music played once and then the game went silent.** The generated WAV files carried no
  loop metadata, and Godot's WAV importer defaults to detecting looping from the file. Every
  track imported with looping disabled, so a stage's music ran for about sixteen seconds and
  never came back. The generator now writes a `smpl` chunk into music and ambience files,
  which is exactly what the importer looks for.

### Added (tooling)

- **Windows and Linux export presets**, so PC and Steam Deck builds are a supported path
  rather than something to improvise. Output goes to `build/`, which is not committed.
- **`tests/AudioCheck.gd`**, run with `godot --path . -- --audio`. Reports the audio driver,
  bus wiring and volumes, whether every sound the code asks for resolves, whether players
  actually enter a playing state, and whether music is set to loop. A headless run uses the
  Dummy audio driver and would report playback that never happened, so this one needs a real
  window. It also ships in exported builds, so a shipped game can be checked in place with
  `SidewalkKings.exe -- --audio`.
- Nine audio checks in the smoke suite covering buses, resolution of every referenced sound,
  and loop flags. Audio fails silently by nature: nothing errors, the game is just quiet.
  The suite is now 157 checks.

### Decided

- Night lighting will use Godot's built-in 2D lights rather than the `lit` addon. Lit
  requires the Forward+ renderer and does not support Compatibility or Mobile; this game
  runs on Compatibility, which is what makes the browser and mobile builds work at all.

---

## Unreleased — Phase 2, Stage 2: the Metro Line

Three new areas past the chained gate at the east end of Lantern Market, a sixth gang,
a second dojo, a second general store, and the opening of chapter two.

### Added

**World**
- **Metro Platform.** A station that is always open and never busy. Turnstiles, a ticket
  machine, a bank of lockers and the second dojo. Reached through the gate in Lantern
  Market once Dez tells you the chain is decorative.
- **Rooftop Route.** Aerials, vents and washing lines above Grease Alley. A way across
  the district that never touches a pavement, which is the point of it.
- **Bellwater Block.** Forty flats and one shop, with the Commuters sat on the wall
  outside it.
- Two connecting doors into chapter one: a metro entrance in Lantern Market and a fire
  escape in Grease Alley, both gated on the story flag that opens the chapter.

**Enemies**
- **The Commuters**, a sixth gang of five: Straphanger, Sprinter, Turnstile, Busker and
  The Conductor. The Conductor is armoured and cannot be grabbed, which makes the
  Bellwater fight a test of the guard and roll added in Stage 1.
- Five new encounters, including a two-front fight on the platform and a mixed wave in
  Bellwater.

**Content**
- **Bex's Metro Line School**, a second dojo teaching four techniques built for fighting
  in a space you cannot back out of: Turnstile Spin, Platform Drop, Closing Doors and
  Last Train. Last Train has armour, so it trades through a jab on the way in.
- **Nadia's Corner**, Bellwater's only shop. Three new foods: Platform Coffee, Bellwater
  Stew and a Lost Property Sandwich.
- Three quests: Mind the Gap, Tuesday's Bag and The Long Way Round.
- Nine new characters and eight new props, all generated.
- A **metro** music track, so the new district is not borrowing chapter one's.

**Tests**
- A **world graph** section: every area has a layout, every door lands on a spawn point
  that actually exists, every door has a return door, the map screen's connections agree
  with the real doors, and every area is reachable on foot from the opening street.
- A **chapter two** section walking the whole loop: the gate is shut before the story
  opens it, each area builds, each spawn puts the player at the right end of the street,
  the camera frames them, the locker that carries the quest flag is searchable, and a
  Commuter actually takes damage.
- The area travel loop is now driven by `ContentDB` rather than a hand-written list, so a
  new area is covered the day it is added.
- The suite is now **197 checks**.

### Fixed

- **The boss health bar could stay on screen forever.** It was only cleared by the boss
  being defeated. Leaving the area mid-fight, or dying and respawning elsewhere, left a
  bar on the HUD for a boss who was not there. It now clears on area load, with a check.

### Changed

- The metro tunnel wall is drawn at 1:1 instead of 2x. At 2x a single tunnel mouth filled
  the screen and read as a black hole rather than a station.
- Rooftop scenery stands on the parapet line. Placed at building height, as street
  scenery is, it floated in open sky, because a roof has no building behind it.
- The interior floors dropped their alternating tile, which was reading as a loud
  checkerboard rather than a floor.

---

## Unreleased — Phase 2, Stage 3: lighting and bloom

Every pixel in the game was a flat, unlit sprite. There were no lights, no shaders, no
particles and no post-processing anywhere in the codebase; the streetlights were pictures
of lamps that emitted nothing. This is the first pass at that, prototyped on one area.

### Added

**Lighting**
- Area layouts gain an optional `lighting` block: an ambient tint and a list of light
  pools. An area without one builds exactly as it did before, so this rolls out one
  street at a time rather than all eight at once.
- **Metro Platform** is the first lit area: cool underground ambient, warm platform
  lights, cold tunnel mouths, and a little colour thrown by the ticket machine and the
  door of Bex's dojo.
- `AreaLighting` builds the `CanvasModulate` and the `PointLight2D` pools; `Renderer2D`
  owns the single `WorldEnvironment` and its bloom settings.

**Bloom, and why it does not smear**
- HDR 2D is on and the glow threshold is exactly **1.0**. Ordinary art clamps at 1.0 and
  therefore cannot bloom however pale it is. Only sprites deliberately pushed above 1.0
  bleed. Without that separation the threshold becomes a fight against every white
  sneaker and lit window in the art, and the result is the vaseline look that gives
  pixel-art bloom its bad name.
- Verified on the Compatibility renderer in a real browser, which is the only renderer
  this game ships. Glow is unsupported on Compatibility before Godot 4.3.

**Emission masks out of the generators**
- `tools/gen_emission.py` derives a mask of just the light-emitting pixels from the art
  itself: lamp glass, ticket screens, vending fronts, metro signs, shop signage, lit
  windows and the near skyline. Seventeen masks, plus four radial light textures.
- Hand-painting these across the art set would be miserable. Deriving them is a loop,
  which is the whole reason this pipeline is generated.
- A declared colour that matches no pixels **fails the build**. Otherwise an art change
  would quietly stop something glowing, with no error anywhere.

**Setting**
- Lighting is a player setting on the pause menu, persisted, and off restores exactly the
  previous look. Toggling it rebuilds the area in place and keeps the player standing
  where they were rather than dumping them back at the street entrance.

### Fixed

- **Emission overlays attached even when lighting was off**, rendering at their raw gain
  and clamping to white. The metro sign became a white rectangle. They are now gated on
  the area actually being lit, which would otherwise have hit all seven unlit areas.
- **The station floor tile had two tones about 40% apart**, which read as a chessboard
  rather than a floor and became the loudest thing on screen once lit. Tiling now reads
  from a grout line instead of from value contrast.

### Measured

Frame cost on an RTX 5080 with vsync disabled, standing in the middle of the platform:

| | Frame time | Draw calls |
|---|---|---|
| Lighting off | 0.44 ms | 26 |
| Lighting on | 0.54 ms | 27 |

A tenth of a millisecond against a 16.7 ms budget here. It is fill rate, though, which
scales with resolution and is far dearer on a phone or a Steam Deck. **Not yet measured on
either**, which is why the setting exists.

### Tests

Twenty-two checks, suite now **219**. The threshold is 1.0 and HDR 2D is on, because if
either drifts every bright pixel in the game silently starts to smear. Every emission mask
has source art and every light texture a layout names exists. A lit area gets its tint,
lights and overlays with the gain compensated for ambient. Lighting off builds none of it.
An area with no lighting block is untouched. Reloading an area keeps the player in place.

### Not done yet

- The other seven areas have no lighting block and are unchanged.
- No normal maps, so light pools are flat rather than shaped by the art.
- No ambient motion, no particles. A still frame still reads as still.

---

## Unreleased — the map, fast travel, and three save slots

Phase 2's last stage, and the smallest: nearly all of it was surfacing capability the data
model already had.

### Added

- **A real map of Riverbend.** Nodes come from `AreaData.map_position` and edges from
  `AreaData.connections`, so the map cannot disagree with the world. Somewhere you have not
  been is drawn as a hollow node with no name, because knowing a place exists and not
  knowing what it is is more useful than not knowing it exists.
- **Fast travel** between visited areas, from the map screen. Refused while an encounter is
  live: leaving a fight through a menu would strand the director running an encounter with
  nobody in it, and would hand the player a free escape from every fight in the game.
- **Three save slots in the pause menu**, each showing level, money, area and playtime.
  `SaveManager` has taken a slot argument since Phase 1 and nothing had ever passed one
  other than zero.

### Fixed by the tests

- **Nothing recorded where the player had been.** The map's visited test read
  `visited_<area>`, a flag no code in the game ever wrote. Every area would have shown as
  unvisited forever, and the screen would have looked entirely plausible while being wrong.
  Areas now set the flag on entry. The check asserts the flag is written, not that the map
  renders, because a map that renders is exactly what the bug produced.
- **The map took nine frames to become navigable.** Centring each label waited a frame, once
  per area, so anything arriving sooner than nine frames found an empty panel. Rebuilt in a
  single pass.
- **A test that depended on the order the tests ran in.** The map check assumed areas were
  unvisited, which was true only until an earlier check visited one. It sets its own state
  now. A test that passes because of what ran before it is not testing anything.

### Changed

- Map nodes are compact hit targets rather than labelled buttons. Nine full-size labels do
  not fit and overlapped into a pile that hid the graph they described. The current area is
  named, and so is whichever node you have selected.

### Tests

Suite is **292 checks**, up from 281. The new ones cover visit recording, that no two areas
share a map position, that the map draws a graph rather than a list, that it offers only
visited destinations and never the current one, that fast travel is refused mid-encounter,
and that the three save slots are genuinely independent.

---

## Unreleased — chapter two, and cutscenes

### Added

- **A cutscene system.** Scripted camera moves, actor blocking, dialogue and the flags
  they set, as a list of steps in `data/cutscenes/<id>.json`. Same shape as an area
  layout and for the same reason: it is a sequence of instructions rather than a set of
  properties, and it changes far more often than the code that runs it.
- Taking control is nearly free: the player already gates its own input on the PLAYING
  state, so switching to CUTSCENE stops the player, the enemy director and the encounter
  triggers without any of them needing to know why. The state existed in the enum from the
  start and had never been used.
- `GameCamera` gains a scripted mode, deliberately separate from `lock_to`: locking
  clamps the player-following camera, scripting replaces it.
- **The Line Office**, a ninth area behind the Metro Platform, opening once the Conductor
  is beaten.

### The answer

Chapter one ended with Big Starch paying four gangs to be *tidy*. Chapter two asks who
paid him, and the answer is nobody. Line 4 was never formally closed, only suspended,
because closing it is a decision and a decision needs a name on it. A suspended line still
draws a budget, a budget has to be spent or it gets reduced, and a reduced budget is
somebody noticing. So a form arrives every Tuesday and a man signs it, and the money goes
to community liaison, which is to say to five gangs, to keep the streets quiet enough that
nobody asks why a closed line is closed.

There is nobody to hit. That is the point, and Dez says so.

### Fixed by the tests

- **A skipped cutscene left the chapter unfinishable.** The flag that ends chapter two was
  set by the last line of dialogue, so skipping the scene skipped the flag. The runner
  applies flag and quest steps even when aborted, precisely so this cannot happen, but the
  content was not using it: story-critical state belongs on a step, not inside dialogue a
  skip bypasses.
- **A flaky combat check.** The telegraph test waited a fixed number of frames for a
  wind-up that is measured in physics frames and starts part way through one, so it failed
  about one run in ten on a system that was working. It waits for the condition now. A test
  that fails at random is worse than no test, because it teaches you to ignore failures.
- **An engine error on every scene teardown.** A dialogue callback outlived its object;
  `Callable.is_valid()` stays true in that case, and asking for the object to check it is
  itself what printed the error. The object id is checked instead, which never
  dereferences anything.

### Tests

Suite is **281 checks**. The cutscene ones assert what actually strands a player: that
playing takes control, that skipping ends, that control and the camera come back, and that
a skipped scene still advances the story.

---

## Unreleased — the whole city is lit

All eight areas now carry lighting, where before only the Metro Platform did. That
inconsistency was worse than nothing being lit: walking out of a lit station into a flat
street drew attention to the flat street.

Each area gets a time of day rather than a generic tint. The ambient colour is the light
that is **not** coming from a fitting, so it carries the hour; the lights are what argues
with it. Where the two agree the result reads as tinted rather than lit, which is the
mistake the first pass at the rooftop made.

| Area | Reading |
|---|---|
| Ferry Row | Dusk. Sky still blue, every lamp just switched on warm. |
| Lantern Market | Early evening, warmer and brighter, shopfronts throwing light on the pavement. |
| Grease Alley | Night. Two working lamps and Pops' doorway. The gaps between pools are the point. |
| Rustpile Yard | Sodium floods. Lit for work, not for people. |
| Starch & Sons | Cold fluorescent, evenly spaced. The only bright area in the game. |
| Rooftop Route | Night above the streetlights. Skylights and a stairwell, nothing else. |
| Bellwater Block | Night. Cool, quiet, and the only warmth is Nadia's being open. |
| Metro Platform | Underground, unchanged from the first pass. |

### Notes

Street lamp pools are generated from the same helper that places the lamps, so a lamp and
its light cannot drift apart when a street changes its spacing.

Two areas needed a second pass after looking at them. Starch & Sons blew out to white,
because full-strength lights were being added to an already-bright ambient; "over-lit"
needs weak lights on a bright base, not strong ones. The Rooftop was a uniform blue wash,
because two very wide fills covered the whole floor evenly. It has discrete pools now.

### Tests

The check that an unlit area stays untouched used to point at Ferry Row, which broke the
moment the last area was lit. It now tests the builder directly with an empty layout, so
the guarantee is about behaviour rather than about which street happens to still be dark.

---

## Unreleased — the streets move

A still frame reads as dead however well lit it is. This is the cheapest fix for that:
a few things in shot that are not holding perfectly still. None of it touches gameplay,
and none of it has collision or state.

### Added

- **Sway.** Washing lines, awnings and rooftop aerials move with the air, each starting at
  its own point in the cycle so they do not all lean in step.
- **Flicker.** Streetlights, the metro sign and lit screens vary in brightness. Modulate is
  inherited by children, so the emission overlay from the lighting pass rides along and the
  bloom pulses with the sprite. Roughly one street lamp in four is on the way out and
  stutters noticeably; a row of identically steady lamps just reads as wallpaper.
- **Litter.** Paper and leaves cross each outdoor street on the wind, wrapping around
  rather than leaving. Interiors get none, because there is no weather in a laundromat.

Across the eight areas: 15 swaying items, 38 flickering, 47 pieces of litter. All of it is
layout data, so a new street opts in the same way it opts into lighting.

### Notes

Everything moves in whole pixels. The project snaps 2D transforms to the pixel grid, so a
sub-pixel sway does not render smoothly, it judders between two positions at an uneven
rate. One or two pixels at a slow rate reads as a breeze; anything finer reads as a fault.

### Tests

Motion is invisible in a screenshot, so it is asserted by watching values change over
time: a swaying sprite moves horizontally and not vertically, a lamp's brightness varies,
litter travels and wraps instead of escaping, and an interior has none of it. Suite is
**271 checks**.

---

## Unreleased — the cast has faces

First pass on character art. Nothing about the fighting changed: the poses, frame counts,
timings and hitboxes are all untouched. These were rendering faults, not art decisions.

### Fixed

- **Every character was faceless.** The eyes were drawn, but as a single dark pixel placed
  flush against the fringe, so they merged into the hair and the face read as a blank
  oval. Eyes are two pixels wide now and sit clear of the hairline.
- **The hair cap reached the middle of the head**, leaving barely seven pixels of face.
  It is shallower, so there is room for a face at all.
- **Limbs merged into the torso.** The renderer drew every part's outline and then every
  part's fill, so a part drawn later erased the outline of the parts before it. The front
  arm lost its rim exactly where it crossed the torso and the two read as one shapeless
  mass. Each part now outlines with its own fill.
- Added a consistent key light from the upper left on heads and torsos, so shapes read as
  solid rather than flat.

### Added

- **Builds per archetype.** Every character used to share one body, so a heavy and a
  rusher had the same silhouette and only the palette told them apart. Torso width, limb
  thickness, head size, overall scale, stance width and hunch now vary by role, and you
  can tell what is coming at you from the outline alone.
- **Clothes read as clothes.** Every top met the neck with the straight edge of the torso
  polygon, so a jacket, a sweater and a suit were the same block in different colours.
  Garments now have a neckline: notched lapels on a jacket, a hood bunched behind the
  neck, a crew neck on a sweater, lapels and a tie on a suit. Sleeves are set in with a
  shoulder seam, and open garments have a hem so they end rather than stopping at the
  waist.
- **Arms read as arms.** They were uniform-width capsules hanging across the chest in one
  flat tone, which looked like a blob of skin stuck to the torso. The forearm is now
  slimmer than the upper arm, every limb breaks at the elbow whether or not a sleeve ends
  there, and the hand is never wider than the wrist.
- Arms hang from the edge of the shoulder, so widening a torso carries them outward with
  it. Broad builds previously kept their arms at the narrow spacing and wore them across
  the middle of the chest.
- The build comes from the enemy's archetype in the game data, not a second list kept
  beside the art. A hand-written copy would drift the moment an archetype changed, and
  the drift would show up as a heavy that looks like a rusher rather than as an error.
  Anything a character sets by hand still wins.

### Fixed (test)

- The menu navigation test nudged a volume slider and never put it back. Those sliders
  write straight through to the saved settings, so **every smoke run turned the master
  volume down a notch**, and after enough runs the suite failed because Master was
  effectively silent. It restores the value now.

---

## Unreleased — the game was unfinishable

### Fixed

- **You could not leave the first street.** Automatic street-edge doors never fired, so
  the game could not be finished, or really started. The door detects the player with
  `body_entered`, which only reports physics bodies, but its collision mask covered the
  player's *hurtbox* layer. A hurtbox is an Area, not a body, so the two could never
  match. Nothing errored, and every other test travelled by calling `SceneManager`
  directly, which bypasses the door entirely. There is now a test that walks the player
  into a door and waits for the area to change.
- While fixing it, a second trap: **`.tscn` has no comment syntax.** A `#` line added to
  explain the mask did not annotate the scene, it broke parsing of every property after
  it, and the mask silently reverted to the default. The explanation lives in the
  generator now.
- **Parallax ran a frame behind the camera.** The Area sits before the Camera in the
  scene tree and neither set a process priority, so the background was placed every frame
  using the *previous* frame's camera position. Standing still it looks perfect; walking,
  the background lags and catches up, which reads as the buildings sliding around loose.
  Measured at up to 1.4 px of error even in a headless run, now 0.00.
- **Buildings floated above the road.** Their heights were written by hand in the layouts
  and did not match the art, so every facade was placed 8 px short, leaving a gap with the
  distant skyline showing through underneath. Buildings are now placed from the same spec
  table the art is drawn from, so the two cannot drift apart, and they stand on the road's
  far edge instead of having their shopfronts hidden behind it.

### Changed

- **Text was rendered without antialiasing while the canvas is scaled by a fractional
  amount**, which gave uneven stroke widths, some two screen pixels and some three. That
  is what read as blurry. The UI font is a smooth proportional typeface, not pixel art, so
  antialiasing and subpixel positioning are now on.
- The text outline dropped from 4 px to 2. At a 9 px font a 4 px outline is nearly half the
  glyph height: it closes the counters and turns small text into a dark smudge.

---

## Unreleased — installable app, and menus you can navigate

### Added

- **The web export is now a real progressive web app.** It is played as an installed app
  on desktop and fused into SteamOS on a Steam Deck rather than opened in a tab, so it
  ships a manifest, an offline page, a service worker and proper icons at 144, 180 and
  512 px, generated from `icon.png` by `tools/gen_pwa_icons.py`. Display is standalone and
  orientation is landscape.
- Pixel art does not survive an arbitrary resize, so each icon is nearest-neighbour scaled
  to a whole multiple first and only then area-averaged down to the exact size. There is
  also a maskable variant with a 20% safe-area inset for Android's circular crop.

### Fixed

- **Menu navigation could not reach the settings without a mouse.** Navigation only ever
  moved through the left-hand menu column, so the volume sliders and the toggles on the
  Settings page were mouse-only. On a controller, which is how this is played on a Deck,
  they could not be changed at all.
- **Selection and focus were two different things.** Each menu kept its own index
  alongside Godot's focus and any mouse click desynced them, so the item that looked
  selected and the item Enter activated could be different ones. Focus is now the single
  source of truth and hovering moves focus, so the two can never disagree.
- **Back always quit the whole menu**, even from deep inside a page. It now steps out one
  level: page, then menu column, then closed.
- The title screen's settings and credits panels fell through the input handler entirely,
  so the game's own movement and confirm keys stopped working the moment one opened and
  only the arrow keys carried on. Both layers navigate identically now.
- **Sliders had no focus state at all**, so there was no way to tell which one was about
  to change. They now highlight with their label.
- **The HTML shell inferred "needs threads" from "has a service worker".** That was
  accidentally correct only while the PWA export was off. Turning it on made the page
  demand SharedArrayBuffer this build does not use, and refuse to start with a browser
  compatibility error. It now reads the exporter's own thread flag.
- The shell was missing Godot's head-include placeholder, so the manifest was generated
  and nothing referenced it, and it never registered the service worker. Both fixed, which
  is what turns "create shortcut" into a real install.

- **Chrome offered no way to install it.** Godot's web export has icon slots for 144, 180
  and 512 only, and Chrome will not offer to install a site unless the manifest declares
  an icon of at least **192** as well as a 512. There is no warning: the manifest is
  generated, the browser reads it, and the install option simply never appears.
  `tools/finish_pwa.py` now completes the manifest after export, adding the 192, a
  maskable icon for Android's circular crop, and the `short_name`, `scope`, `theme_color`
  and `description` Godot does not write. CI runs it and then fails the build if the
  manifest is not installable.

### Verified since

The service worker **does** register on the live site. The earlier failure was the local
browser, where even a minimal control worker fails to register, so offline caching is
working after all. Launching with no connection is still worth a real-device check.

### Tests

Suite is **249 checks**, including menu navigation driven through the real input handler
and file-level guards on the PWA export configuration.

---

## Unreleased — the web build was silent

### Fixed

- **The browser build produced no audio at all.** Not quiet, not the wrong track:
  literal digital zero, measured with an independent analyser tapped onto the page's
  audio output rather than by asking the engine.

  The cause was **creating audio buses at runtime**. `AudioManager` built its five buses
  with `AudioServer.add_bus()` at startup, which is fine on desktop and silences a web
  export completely. Bisected in a minimal project down to that single call:

  | | Peak | Polls with signal |
  |---|---|---|
  | No `add_bus`, player on Master | 1.1537 | 149 / 149 |
  | `add_bus` x4, player on Master | 0.0000 | 0 / 111 |

  Nothing errors. Buses report correct names, sends, volumes and mute state; players
  report playing with positions advancing; the output is zero. That is why this survived
  three rounds of "the audio is fixed": every check asked the engine whether it thought
  it was playing, and it always thought so.

  Buses now come from `default_bus_layout.tres`, loaded before the audio driver starts.

- **The first track of a session parked at its fade floor.** With the buses fixed the
  build made sound, but around -40 dB, audible only as a drone. `play_music` started
  every track at -40 dB and relied on a tween to raise it. Fades are now stepped by hand
  in `_process`, as `SceneManager`'s screen fade already is, and a track with nothing to
  cross-fade from starts at full volume. The worst a stalled fade can now do is skip a
  transition.

  Measured on the real web build: **0.0000** before, **0.0072** after the bus fix alone,
  **0.7207** with both, against the track's own peak of 0.78.

### Changed

- `AudioCheck` now ends by asking the meter instead of the engine: is there signal on the
  Master bus, and did the fade finish. It **fails** on the Dummy driver rather than
  reporting AUDIO OK, because a headless run cannot hear anything.
- The smoke suite guards the two failures structurally, since it cannot measure signal
  headlessly: no `add_bus`, no tweened fades, the layout resource exists, every bus is
  present at startup. Suite is **227 checks**.

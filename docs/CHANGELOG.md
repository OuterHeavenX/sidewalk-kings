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

## v0.7.0 — ground, facades, and the first shader

### Ground that does not read as a grid

Every surface was one 16px tile repeated, or two alternating in a strict checkerboard. At
16px that pattern is the loudest "this is a tile map" signal in the picture — louder than
the palette or the sprites, because the eye finds a grid instantly.

Surfaces now have variants with cracks, wear, patches and stains, scattered deterministically
by world position: the same street looks the same every time you walk into it, and the grid
is gone.

**Tuned down after looking at it.** The first pass put a 4-9px stain at 0.82 shade on a 16px
tile and gave one to roughly three tiles in four. The pavement swapped a visible grid for a
visible rash. Stains are small and barely darker now, and the scatter is weighted towards
clean — most of a street is plain, with something to notice now and then.

### Facades that have stood outside

Brick that is not all one colour, sills and lintels, the dirt that washes off a sill and
runs down the wall, downpipes with brackets, a string course every few floors so a tall
facade is not one flat sheet with holes in it, and grime where the pavement splashes the
base.

### The first shader

Wet streets. Two things happen to a road when it is wet — it darkens and deepens, and long
soft bands of reflected light slide across it — and this does both with no screen reads,
because the game runs on the Compatibility renderer for WebGL2 and mobile where reading the
screen in 2D is a trap.

Two things it has to get right:

- **The pattern is computed in world space, not UV space.** Ground is hundreds of 16px
  tiles, so a UV-driven pattern restarts inside every tile and paints a grid straight back
  on top of the one the variants were added to break up.
- **It stays below 1.0.** Glow threshold is exactly 1.0, so a brighter highlight would bloom,
  and a blooming pavement is not a highlight, it is a bug.

Wetness is a layout property, so it is on outdoor streets and off in interiors and the
tunnel.

### Fixed on the way

**Area.gd carried its own copy of the tile order** — an array of names that had to match the
generator exactly, in a different language, with nothing checking. Adding a single tile
shifted every index after it and every ground in the game would have drawn the wrong cell of
the sheet, silently. The index is generated to `data/tiles.json` now, and a check asserts
that every tile any layout asks for actually exists.

### Tests

Suite is **392 checks**. The new ones cover the tile index shipping and agreeing with the
layouts, the common surfaces having variants, and the shader being applied on wet streets
and not indoors.

---

## v0.6.0 — the bot plays it, and four ways it could not be finished

A bot that plays the game from New Game to the credits, and the bugs it found. It walks with
the movement actions, fights with the attack actions, talks to NPCs and opens doors, and it
never sets a story flag itself — so a flag that does not get set is the game failing.

Four progression bugs, none of which the 383-check suite could see, because every one of
them left the *systems* working perfectly. The areas built, the doors opened, the fights
ran. The story stopped.

### 1. Chapter one could not be finished

`chapter_1_done` came only from the `q_starch` quest reward, and Dez only hands out
`q_starch` if you walk back to Ferry Row after clearing the laundromat guards and before
fighting Big Starch. Beat the boss without it and `once_flag` closes that encounter forever:
the quest can never complete, the metro never opens, chapters two and three are unreachable.

`starch_defeat` — the dialogue written to set the flag, carrying the Tuesday-money reveal
that sets up all of chapter two — **was referenced by nothing**. It existed as a resource no
code mentioned. Nobody had ever seen it. Beating Big Starch now plays it and grants the flag.

### 2. Entry events fired for exactly one area

`run_entry_events()` was called only in `Game._ready()`, so an area's `on_enter` ran only for
whichever area the game booted into. Walk into any other area and its entry events never
happened. The Line Office arrival is what sets `chapter_2_done`, so walking in did nothing
and chapter two could not be completed — you stood in an empty office and the story stopped.

### 3. Walking away from a fight left the area in combat forever

Encounter spawns used the ordinary 190px aggro range, which is right for someone loitering
on a street and wrong for someone the director just sent to attack. Leave mid-fight and the
spawns sit idle at the far end: the encounter never ends, so the camera stays locked, the
battle music keeps playing and fast travel keeps refusing, with nothing on screen to say the
area still thinks you are fighting. The bot found it stranded 900px from three Pigeons who
had never looked up.

### 4. Cutscenes outlived the areas that started them

Found by adding comic panels: the opening runs long enough to survive an area change, at
which point it drives a freed camera and blocks the next area's own opening from ever
starting, because only one scene may play at a time. `load_area()` aborts any running scene.

### Comic panels

Story beats can be told as wide panels now. The art is generated like everything else —
composed from the same skyline, facades and character sprites the game is built from, so a
panel costs about 80 KB rather than three megabytes — and the words are **not** baked in:
there is no font in the art pipeline, and text painted into a PNG cannot be restyled or
translated and is blurry at every scale but one. `ComicPlayer` draws the bubble at runtime.

A comic is a cutscene step, so it inherits the flag and quest steps and the skip safety. It
also carries a per-panel dwell and stops on abort, because a full-screen thing that responds
only to input is a soft-lock waiting for a player who does not know it wants a key.

The opening is four panels, then the conversation that was always there.

### It can be finished

Seven attempts, six of which found something. The seventh walked the whole story:

    chapter 1 done    true
    chapter 2 done    true
    chapter 3 done    true
    === THE GAME CAN BE FINISHED ===

78 minutes of in-game time, level 11, one death. That is the first time anyone or anything
has reached the end of Sidewalk Kings.

### Also

- **Dez tells you what to do.** Ordered hints with a guaranteed unconditional fallback, so
  there is no state where the game has nothing to say. He says it instead of "...", and the
  pause menu's Quests page leads with it and names the area to head for.
- **Enemies read the fight.** They punish a whiff, they guard (lights absorbed, heavies
  break through), and rushers and ranged slip a wind-up. The first version let *everyone*
  back off on every wind-up, which made fights unwinnable rather than hard: attacking roots
  the player, so an enemy that steps back each swing drifts away faster than you can close.
  The bot hung on a Ferry Row fight that could not end, and a person would have felt it as
  the enemy running away for the entire encounter.

### Tests

Suite is **386 checks**, plus `--play`. Each of the four progression bugs now has a check
that would have caught it, and all four are about the *story* advancing rather than about a
system working -- which is the distinction that let every one of them ship.

---

## v0.5.0 — a bot that plays the game, and the softlock it found

### The game could not be finished

Asked to confirm the game was beatable, I wrote something that plays it: `--play` starts a
new game and walks the whole story with the real movement, attack and interact actions. It
never sets a story flag itself, so a flag that does not get set is the game failing, not the
bot being told to pretend.

It found a **permanent softlock in chapter one**, and it is the reason the game could not
be finished.

`chapter_1_done` came only from the `q_starch` quest reward. Dez only hands out `q_starch`
if you walk back to Ferry Row **after** clearing the laundromat's guards but **before**
fighting Big Starch. Beat the boss without it and `once_flag` closes that encounter forever:
the quest can never complete, the metro never opens, and chapters two and three are
unreachable. Nothing errors. Nothing on screen says anything.

The dialogue written for this — `starch_defeat`, which sets the flag *and* carries the
Tuesday-money reveal that sets up the whole of chapter two — **was wired to nothing at all**.
It existed as a resource that no code referenced, so no player had ever seen it.

Beating Big Starch now plays it and grants `chapter_1_done` directly.

### The ending only played if you left and came back

Chapter three's closing scene hung off the substation's `on_enter` block, and you are
already standing in the substation when you beat the Foreman. It could only fire if the
player walked out and back in again, which almost nobody would do. The chapter still
completed, because the clear dialogue sets the flag, so nothing looked wrong — the scene
written for the ending simply never happened.

Areas support `on_clear` now: events that belong to winning a fight rather than to walking
into a room. It waits for the encounter's own clear dialogue to finish first, since the
director starts that 0.6s after the fight ends.

### Dez tells you what to do

The same investigation showed the progression *depends* on walking back to Dez between jobs
and never says so. That is not a bug a flag fixes; somebody has to say it in words.

Hints are an ordered list in `data/hints.json`, first match wins, with a guaranteed
unconditional last entry — there is no story state in which the game has nothing to tell
you. Dez says the current one whenever he has no story dialogue queued, instead of "...",
and the pause menu's **Quests** page leads with it and names the area to head for.

### Enemies read the fight

Until now an enemy decided what to do by rolling dice against its aggression without ever
looking at the player. Three additions, all reading the player's own attack phase, which
the game already tracked exactly:

- **Punish.** An enemy in range while you are in recovery attacks. No dice roll. Whiffing
  costs something now, which was the biggest thing missing from the fight.
- **Guard.** Enemies can block. Light hits are absorbed, heavies break through — the same
  rule you live under, so it teaches the answer rather than just being harder. Short, on a
  cooldown, and dropped the moment a hit lands, because a guard you cannot get through is a
  wall rather than a difficulty.
- **Respect.** Some step out of range when you wind up instead of walking into it.

Rushers never guard and heavies guard most, so a crowd keeps its texture.

Difficulty comes from these rather than from bigger numbers: an enemy that punishes a whiff
is harder in a way you can learn, an enemy with 40% more health is only slower to kill.

### Tests

Suite is **373 checks**, plus the playthrough. The new ones cover the hint system never
coming up empty (all 15 states produce a distinct hint), and the AI behaviours, which are
invisible when they break — an enemy that stops punishing whiffs still walks, still swings,
and the fight just goes quiet.

---

## v0.4.0 — louder music, harder hits, and blood

### The fight music never actually changed

This was asked for as "make it more action", and it turned out not to be a tuning problem.
`play_music` returns early when the id has not changed, and **almost every encounter named
the track its own area was already playing** — `alley_ambush` asked for `alley` inside
Grease Alley, whose music is `alley`. The switch existed in the data, looked correct, and
fired essentially never. Of twenty-one encounters, two changed anything.

Fights now use a **battle** track, which no area uses, so the change always happens.
Encounters derive it from the helper rather than naming it each: a fight gets `battle`
unless it has a `boss_id`, and then it gets `boss`. Eighteen hand-written restatements of
area music are gone.

The switch back was already fine — `Area.on_encounter_cleared` restores the area track and
the director calls it.

**Boss rooms got a new problem out of the same check.** Both boss areas played the `boss`
track on entry, so walking in blew the reveal and the fight starting changed nothing. They
have a **tension** track now: slow, sparse, mostly space. The room sounds like a room, and
then the boss theme lands.

### The whole soundtrack is faster

Tempo and drum density across every track, and the leads brought up so they cut:

| | was | now | | | was | now |
|---|---|---|---|---|---|---|
| title | 104 | 118 | | industrial | 140 | 150 |
| street | 122 | **138** | | metro | 128 | **142** |
| market | 134 | 146 | | boss | 158 | 166 |
| alley | 112 | **130** | | victory | 120 | 132 |
| shop | 98 | 110 | | battle | — | **152** |

### Impacts

Landed hits throw a burst that punches past its own size before settling, plus streaks
along the direction of the blow — a radially symmetric spark cannot say which way a punch
went. Three variants, picked by what hit you rather than by what sprite threw it, so a bat
always reads as a bat.

### Blood

Droplets arc out of a hit, accelerate downward, land on the floor and stay as stains. They
sit under the actors and over the road, squashed, because the floor is seen at an angle.

**They leave with the body.** An enemy clears its own stains as it fades, which is the whole
point: blood that outlives the person who bled it turns a street into a permanent record of
every fight that ever happened there.

**Tuned down twice after looking at it.** The first pass bled on every connected hit with no
size limit, and six seconds of brawling produced a wall of bright red. Light hits mostly do
not bleed now, stains are smaller, fainter and darker, and no actor may leave more than four
before the oldest fades.

### Tests

Suite is **357 checks**. The new ones assert that every fight changes the music (the check
that found the boss rooms), that the effect art exists, that a landed hit leaves blood, that
it is capped, and that it leaves with the enemy that bled it.

**Fixed while writing them:** the cap check killed the enemy on its way to the cap and then
measured an already-cleared list, so it passed without testing anything. It tops the enemy
up between blows now.

### Not verified

The music is faster and busier by measurement — tempo, drum hits per bar, note density —
but nobody has heard it. Tempo and density are reliable levers; whether it is *better* is
a judgement this pass could not make.

---

## Unreleased — the map is rooms now

Asked for as a metroidvania-style map.

### What changed

The map drew every area as an identical dot. Riverbend is not made of identical dots: the
Line Office is a 700px room and the Line 4 platform is 1560px of street, and a map that
draws them the same is throwing away the most useful thing it knows.

Areas are rooms now, **sized to the street they actually are**. Nothing about that is
authored: box widths come from `walk_max_x` in the area layout, arrangement from
`map_position`, joins from `connections`. Districts get a colour derived from the district
name, so a district reads as one place without a table here that would go stale the first
time somebody adds one.

Joins are drawn as a doorway in each wall with a corridor between. The first attempt drew
them centre to centre, which put a diagonal straight through the middle of every room the
line passed over: the map read as scribble laid across boxes rather than as somewhere you
could walk.

**Fog.** A room you have not been to is drawn as a bare outline if somewhere you *have*
been opens onto it, and not drawn at all otherwise. Knowing a door leads somewhere without
knowing where is the whole shape of a map like this.

### About the addon

The `MetroidvaniaSystem` addon was parked out of the project on 4 September along with
seven others, for the reason recorded in `ParkedGodotAddons/README.md`: several hundred
import errors on every launch. This screen does not use it, and that is a judgement worth
stating rather than burying.

MetSys models a world as a grid of cells where **each room is a scene file**, discovered by
the player entering that scene. Sidewalk Kings has no per-area scenes at all — one
`Game.tscn` builds every street at runtime from JSON — so the part of MetSys that does the
work would have had nothing to hook into, and what was left would have been its drawing
code fed a grid invented to satisfy it. It also ships `class_name MapView`, which the game
has already used since Phase 2, so enabling it is a hard registration conflict.

Using the game's own geometry got the same look with less machinery. If the addon itself is
wanted rather than the map style, say so and it can be wired up properly.

### Tests

Suite is **345 checks**. The new ones cover what a box-based map can get wrong that a graph
of dots could not: that no two rooms overlap (two areas drawn as one room still looks like
a map, just the wrong one), that every area gets a room, that a longer street is drawn as a
wider room, and that the fog rule shows what is next door and hides what is not.

**Fixed while writing them:** the fog check asserted the substation was hidden, which was
only true until an earlier test walked chapter three. It builds and restores its own world
state now. That is the third time a check in this suite has quietly depended on the order
the suite runs in.

---

## v0.3.0 — Chapter three: the line that was never closed

Chapter two ended with a man at a desk explaining that nobody is behind any of it, and
offering Kip the form. Chapter three is what taking it costs.

### The answer, one size larger again

Kip expected the gangs to turn on each other over the missing Tuesday money. What actually
happens is the other half of what the manager said, which nobody heard at the time: *a
reduced budget is somebody noticing*. An unspent line gets audited. An audited line gets
closed properly. Closing it takes the station, and the station is Bellwater's only way in
or out.

So the antagonists are a decommissioning crew with a work order that has a date on it.
They are not cruel and they are not paid by anybody interesting. They will take a
neighbourhood apart because the paperwork says Thursday.

And it hands the five gangs the one thing eleven years of liaison money had been buying to
prevent: a reason to be in the same place, loudly, on the same side.

### Added

- **Three areas**, and the first in the game with no daylight in them: the **Service
  Stair**, **Line 4** itself, and the **Substation**. Underground, the only light is light
  the crew plugged in, so tripod work lamps do nearly all of it and the two surviving strip
  lights are cold and useless.
- **The Closure Crew**: Marshal, Cutter, Roller, and **the Foreman**, who is the only one
  in a white hard hat and the only one holding paper. They hit harder than the Commuters
  and taunt less, because nobody here is defending a street.
- Two quests, a closing cutscene, and reactions from Dez, Nadia and the manager that track
  which side of the decision you are on.
- New art: a tunnel wall with exposed cable runs and dead strip lighting, a substation
  wall, and worksite props — tripod lamp, hazard barrier, cable spool, switchgear.
- **A doorway sprite.** The game had none: every interior door until now was either painted
  onto a shopfront or invisible.

### Fixed by the tests

- **Two of the new doors were invisible**, and the check written last release caught them
  the moment they existed rather than after somebody played twenty minutes to reach one.
  That check has now paid for itself on content that did not exist when it was written.
- **A drop that could never drop.** The Cutter was set to drop a pipe, which is a weapon;
  `ContentDB.get_item` resolves items, foods and books only, so the pickup would have
  silently fallen back to a burger icon.
- **The substation floor was a wall.** The `metal` tile is vertically grooved and reads as
  corrugated siding; laid across the ground it looked like the player was standing on the
  side of a shed. Only visible by looking at it.
- **A test that broke the next test.** The ending-cutscene check aborts mid-line, which
  leaves the dialogue box on screen, and the boss test after it then failed for reasons
  that had nothing to do with bosses. It cleans up behind itself now.

### Tests

Suite is **338 checks**. The chapter-three ones assert the shape of a story that can strand
a player: that taking the form is the only key to the stair, that the substation is behind
the platform fight, that every underground area carries its own lights, that the crew are
three different fighters rather than one repeated, and that skipping the ending still ends
the chapter.

---

## v0.2.0 — builds that update, and say which build they are

The release that makes releases work. Asked for as "add the version # in the main screen
and in the menu", which turned out to be two separate problems wearing one coat.

### The version is on screen and means something

It was already on the title, at size 8 in `TEXT_DIM`, in the corner — a smudge. In the
pause menu it was a row inside the **Settings** page, three inputs from anywhere and the
last place you look. Both are readable now, and the pause menu carries it on the footer of
every page.

More to the point, **every deploy so far reported v0.1.1**, so the number could not answer
the only question anyone asks it: am I running the update or the old one? Builds now carry
the commit they were made from, stamped by `tools/stamp_build.py` in CI:

    v0.2.0  ·  a1b2c3d 2026-09-06

A build made from a dirty tree gets a `+`, because a build that is not the commit it claims
to be will otherwise have you chasing a bug that exists only on one desk.

### The app can update itself

An installed app that cannot update itself is not really installed, it is stranded.

Godot's service worker already knows how to step aside — it handles `claim` and `update`
messages — but **nothing ever sent one**. A new worker installed, moved to WAITING, and
stayed there while the old one kept serving `index.pck` from cache. `index.pck` is the
entire game, so the app went on launching an old build, reporting the same version string,
looking perfectly healthy. The only escape was a hard refresh, which is not something you
can ask of somebody who installed this on a Steam Deck.

The shell now watches for a waiting worker, and the rule is never to interrupt play:

- Update found in the first minute → applied immediately and the page reloads. You are
  almost certainly still on the title screen.
- Later than that → the new worker takes over without touching the running page, and the
  next launch is the new build.

It also calls `registration.update()` on load, because browsers check for a new worker on
their own schedule — up to 24 hours — and an app that is launched, played and closed may
never reach it.

### Fixed before it shipped

- **The build stamp did not survive the export.** Written first as `data/build.txt`, and
  the export preset excludes `*.txt` and includes `*.json`. The file was generated,
  committed, and silently dropped from the package: the exported game reported `dev` and
  looked entirely correct. It is `data/build.json` now, and a check asserts that a stamped
  tree produces a build that knows its own commit.
- The title's version label was clipping off the right edge once the commit was appended.

### Tests

Suite is **302 checks**. The new ones cover the version being set, the stamp file shipping
as an exportable resource, a stamped build reporting its commit rather than `dev`, and the
version line the player actually reads containing both halves.

### Known: not verified in a real browser

The update flow is **reasoned and syntax-checked, not observed**. Service workers do not
register in the preview browser available here, and the Chrome bridge was not connected, so
nothing has watched a real browser take a second build. The first proof will be the next
deploy after this one.

**One more hard refresh is needed.** The shell currently installed on your device has no
update handler, so it cannot fetch its own replacement. Refresh once to pick up this build;
after that it maintains itself.

---

## Unreleased — playtest fixes: doors you can see, punches you can feel

The first full playthrough. Everything below came from it, and all of it is the same
defect wearing different clothes: something existed, worked correctly, and never announced
itself.

### The roof route was unfindable

Getting onto the roofs from Bellwater is an automatic street-edge door — you walk into it.
Coming down puts you in Grease Alley, three areas earlier. Getting back up was a
**non-auto, mid-street interact door at x=620** with **no art of any kind**: an invisible
24x40 trigger in front of a plain brick facade, and `lamp_row` put a streetlight at exactly
x=620, so a lamp stood in front of a door nobody could see. The only way to find it was to
walk the street pressing the interact key.

- **Fire escapes are drawn now.** There was no fire escape sprite in the game at all. The
  new one has three landings, stair runs and a drop ladder hanging within reach, because
  the entire job of the sprite is to say "you can climb here" from across the street.
- The Grease Alley door moved to clear wall at x=743 and now sits on the art.
- **Bex's dojo on the metro platform was invisible too** — the only shop in the game with
  no shopfront, just a bare stretch of platform wall with a trigger in it. Found by the new
  check, not by playing.

### Doors announce themselves

Every interactable door now carries a chevron that fades in from about 108 px and brightens
past 1.0 into the bloom when you are close enough to use it. Locked doors show it too: a
door you cannot open yet is information, and a door you cannot see is a dead end that looks
like a wall. The HUD prompt still exists, but at 26 px it only ever told you about a door
you were already standing in.

### Punches now land

Reported as "the swing effects are great, but no punch when it lands". Measured, the
complaint was exact: `hit_light` was **-25.0 dB RMS against a -16.7 dB whoosh**, so the
wind-up was 8 dB louder than the impact it led into. Its deepest component was a 300 Hz
sine dying in 40 ms — there was nothing below 300 Hz in a punch landing.

The sounds had normalised to a loud *peak* (-1.6 dB) and read as fine. Peak says nothing
about how hard something lands; a click and a thump can share a peak and differ by ten
decibels of energy.

- Impacts rebuilt with contact, meat and a low thump, soft-clipped so they survive a phone
  speaker that cannot reproduce the bottom octave at all.
- **Kicks have their own impact.** Every kick in the game landed with the sound of a
  haymaker, so a combo read as one repeated noise rather than as different limbs.
- Weapon hits and crits had the same defect, exposed only once the fists were fixed: a bat
  measured quieter than a bare jab, and a crit quieter than a normal heavy.
- The hit sound is now derived from `damage_kind` rather than repeated on every move. Nine
  kicks each passed `hit_sound="hit_heavy"` by hand and no single place made that look
  wrong.

| | swing | impact |
|---|---|---|
| light | -16.7 | **-15.1** |
| heavy | -18.0 | **-11.8** |
| kick | -23.0 | **-11.7** |
| weapon | -18.0 | **-13.7** |
| crit | | **-9.2** |

### Fixed by the tests

- **The door-art check called four visible doors invisible and missed the one that was
  not.** It compared the door's x against each scenery sprite's anchor, but scenery is
  anchored top-left and a shopfront is 126 px wide. Measuring against the sprite's extent
  found Bex's dojo, which nothing was covering.
- **The loudness checks measured nothing at all.** Written first as GDScript reading
  `AudioStreamWAV.data`, they reported about -5 dB for every sound: Godot imports WAVs as
  QOA, so that buffer is compressed bytes and decoding it as PCM produces noise. An
  instrument that returns a plausible number for everything is worse than none, so the
  check moved to `tools/check_audio.py`, beside the generator, where the sources are PCM.

### Tests

Suite is **297 checks**, plus `tools/check_audio.py`. The new ones assert what the player
can *see* and *hear*, which nothing here tested before: that every interactable door has
art reaching it, that the fire escape door stands on the fire escape, that doors build a
marker, that every move's impact sound exists, that kicks do not land as punches, and that
every impact outweighs the swing before it.

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

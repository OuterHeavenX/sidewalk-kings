# Phase 2 — Combat depth, then the city

Phase 1 proved every system works. Phase 2 makes the fighting worth doing more of, then
uses the content pipeline to grow the city on top of the improved feel.

**Order matters.** Combat changes come first, because content built against the current
combat would need rebalancing once the player gains a defensive option and enemies start
flanking.

---

## Where the game actually stands

Honest read after building and testing the slice:

**What works.** The combo chain has real texture: the cancel window only opens on a
connected hit, so whiffing commits you. Weapons meaningfully change a fight. Money and
shopping drive a genuine build. The boss reads.

**The hole.** The player has no committed defensive option. Against an incoming attack your
choices are outspacing it in the lane, jumping over it, or trading. Counter Stance exists
but is a purchase deep in the dojo, not a baseline verb. In a brawler where crowds are the
threat, that flattens fights into the same exchange.

**The other half of the same problem.** Enemies circle and space themselves, but never
coordinate. A group of four is not meaningfully more dangerous than two, because they all
approach from whichever side they happen to be on. Threat and answer have to arrive
together, or one just makes the game easier.

---

## Stage 1 — Combat depth — **done**

### Guard

A held defensive stance. Not a hard counter, a resource trade.

| Property | Value |
|---|---|
| Input | Hold the sprint input while stationary; keyboard Shift, gamepad LB, plus a sixth touch button |
| Effect | Incoming damage heavily reduced, knockback reduced, no knockdown from light attacks |
| Cost | Drains energy while held; cannot guard at empty energy |
| Break | Heavy and armored attacks break the guard and stagger you |
| Cannot | Move, attack or grab while guarding |

Guarding is a decision with a price, not a safe default. Running and guarding share an
input because you are never doing both: the input means "commit", and direction decides to
what.

### Dodge roll

A short committed movement with invulnerability frames.

| Property | Value |
|---|---|
| Input | Double-tap a direction |
| Effect | Rolls a fixed distance, invulnerable for most of it |
| Cost | Energy |
| Recovery | Cannot attack during the roll, brief recovery after |
| Follow-up | **Dash Strike**, already in the dojo, becomes the roll's cancel |

This reuses the double-tap detection and the `dash_time` field that are already scaffolded
in `Player.gd` but currently unused. It also gives Dash Strike a real identity: it stops
being a standalone lunge and becomes the aggressive answer to a well-timed roll.

### Enemy flanking

`EnemyDirector` gains awareness of the group rather than leaving each enemy to decide alone.

- The director assigns **engagement slots**: front, back, and waiting.
- A back-slot enemy paths around the player through the lane rather than approaching head on.
- Only one or two enemies hold an attacking slot at a time; the rest circle or wait, which
  is what keeps a crowd readable instead of a pile-on.
- Slots are reassigned when an enemy is knocked down or defeated.

This builds on the existing `slot_index` field, which is currently assigned and unused.

### Clearer telegraphs

Guard and dodge only matter if attacks can be read.

- Heavy and armored enemy attacks get a visible wind-up tell, the same treatment Big
  Starch's slam already uses: a colour flash plus a longer startup.
- A short audio cue on the wind-up, so a tell off the edge of the screen is still fair.

---

## Stage 2 — The district beyond the gate — **done**

The pipeline proof: new areas with no engine changes.

- **Metro Platform** — where the Tuesday money arrives. Interior, tiled, turnstiles and a
  bank of lockers.
- **Rooftop Route** — a traversal area above Grease Alley, reached from the fire escape.
- **Bellwater Block** — residential, the Commuters' home ground, at the end of the line.
- The Commuters: five enemies reusing existing archetypes with new data. The Conductor is
  armoured and ungrabbable, which is what makes Stage 1's guard and roll load-bearing.
- Bex's Metro Line School teaching four close-quarters techniques, and Nadia's Corner.
- Three quests, three foods, five encounters, nine characters, eight props, one music track.

### What it proved

**No engine change was needed for content.** Three areas, a gang, two shops, three quests
and a music track went in through the generators and the JSON layouts alone. The data model
has no gap here.

**Two engine-side findings, both recorded and fixed:**

- The boss health bar was only ever cleared by the boss being defeated. Leaving an area
  mid-fight left it on the HUD indefinitely. Found by a screenshot, not a test, which is
  why the world-graph and chapter-two test sections now exist.
- The smoke suite's area travel list was hand-written, so three new areas were silently
  uncovered until the list was changed. It now iterates `ContentDB`.

**One art-side finding.** Rooftop scenery placed at building height floats in open sky,
because a roof has no building behind it. Street placement conventions do not transfer to
an area with no street. Recorded in [ART_DIRECTION.md](ART_DIRECTION.md).

## Stage 3 — Connective tissue — **done**

- A real map screen that draws the connection graph from `AreaData.connections` instead of
  a list of names.
- Fast travel between visited areas, refused while an encounter is live.
- The three save slots exposed in the UI; `SaveManager` already supported them.

**What it proved.** Almost none of this was new capability. `AreaData` already carried
`map_position` and `connections`, and `SaveManager` had taken a slot argument since Phase 1.
The work was surfacing what already existed, and the one thing genuinely missing was a
record of where the player had been: the map's "visited" test read a flag that nothing in
the game ever wrote, so every area would have shown as unvisited forever and the screen
would have looked plausible while being wrong. That is the shape of failure this project
keeps meeting, and it is why the check that catches it asserts the flag is written on
entry rather than asserting the map renders.

The second lesson was a presentation one. The first version put a full labelled button on
each node, which is the obvious thing to do and does not survive nine areas: the labels
overlapped into an unreadable pile and hid the graph underneath. Nodes are compact hit
targets now, and a name is drawn for the current area and whichever node is selected,
which is the only one you need named.

## Stage 4 — Chapter two — **done**

The cutscene system and the Line Office. See the changelog for the story; the short version
is that the money comes from a line that was never formally closed, and there is nobody to
hit.

**What it proved.** The one genuinely new system in the phase turned out to be small,
because the game state machine already had a `CUTSCENE` state and every system already
gated on `PLAYING`. The expensive part was not taking control, it was giving it back
safely: a scene that ends without restoring control, or that is skipped and leaves a flag
unset, strands the player in a game that no longer responds or no longer progresses.

---

### Stage 4, as originally planned

- Who sends the money, and why a laundromat.
- Light cutscene support: scripted camera moves and actor blocking. The one genuinely new
  system in the phase.

---

## Stage 5 — Lighting and bloom — **done**

All eight areas, each with its own time of day. Ambient tint plus light pools from layout
data, and selective bloom driven by emission masks the art generator derives from the art
itself. Prototyped on the Metro Platform, then rolled out once the approach held up.

**What it proved.** The full 2D polish toolkit works on the Compatibility renderer in a
browser: canvas lights, screen-reading shaders, and `WorldEnvironment` glow. Glow in
particular had been assumed unavailable, which was true on Godot 4.0 to 4.2 and is not
true now. Nothing about shipping to the web blocks this.

**The load-bearing trick** is HDR 2D with the glow threshold at exactly 1.0, so ordinary
art clamps and cannot bloom, and only deliberately overbright emission does. That is what
makes bloom safe on a 480x270 frame instead of a smear.

**Still open:** normal maps so light pools are shaped by the art rather than flat, and a
fill-rate measurement on a phone and a Steam Deck.

---

## Stage 6 — Ambient motion — **done**

Sway on hanging scenery, flicker on light sources, wind-blown litter on the outdoor
streets. Not in the original plan; added because a perfectly lit still frame still reads
as dead.

---

## Stage 7 — Character art — **done**

Not in the original plan either. Faces, per-part outlines, per-archetype silhouettes,
arms that read as arms, and garments with necklines. Four passes, none of which touched
the fighting: hitboxes are move data and were never tied to the sprite.

---

## What is left in this phase

Nothing. All seven stages are done and the suite is green at 292 checks.

**What that does not mean.** Phase 2 is complete as specified, and the specification never
included the things that still worry me most:

- **Performance has never been measured on the Steam Deck or a phone.** It is measured on
  this desktop only. Lighting, bloom and ambient motion were all added since the last time
  anything was profiled anywhere.
- **The PWA has never been launched offline on a real device.** The service worker is
  installed and the manifest validates; that is not the same as confirming it starts with
  the network off.
- **Nobody has played the game end to end.** The door out of the first street was broken
  until this phase, so a full run was not possible before now. It is possible now and it has
  not been done.
- **The economy has never been balanced against real play**, only against the smoke test,
  which buys things in an order no player would.

These belong in Phase 3, and none of them should be described as done until someone has
actually sat down with the game.

---

## Night lighting

Wanted: streets, shopfronts and the metro lit by real light sources rather than painted-in
shading.

**Decision: Godot's built-in 2D lights, not the `lit` addon.**

`lit` requires the **Forward+** renderer and explicitly does not support Compatibility or
Mobile. This project runs on **Compatibility**, and that is load-bearing rather than
incidental:

- It is what makes the WebGL 2 browser build work at all.
- It is the correct target for mobile browsers, which is the stated first platform.
- Forward+ in a browser needs WebGPU, which is not broadly available and is certainly not
  available on the mobile browsers being targeted.

Switching renderers to gain the addon would trade the entire web and mobile target for a
lighting feature. That is not a trade worth making.

Godot's own `PointLight2D` and `CanvasModulate` work on Compatibility. The addon's headline
feature is removing a roughly fifteen-lights-per-object cap; a street shows about six at
once, so the cap is irrelevant here.

`lit` stays parked. If the game ever ships a desktop-only Forward+ build, it is worth
revisiting there.

### Plan

- A `CanvasModulate` per area, tinted from `AreaData`, so dusk streets and the strip-lit
  laundromat differ.
- `PointLight2D` on street lamps, shop windows and the vending machine, placed from the
  area layout so it stays data-driven.
- A soft light following the player, so the character never sinks into shadow.
- Light energy and colour exposed in the layout JSON, like every other area property.

---

## Definition of done

Each stage ends the way Phase 1 did: a playable committed build, the smoke test green, and
the web export refreshed.

Stage 1 specifically adds these checks:

- Guarding reduces damage taken, and drains energy
- Guard breaks against a heavy attack
- Cannot guard at empty energy
- Dodge rolls move the player and grant invulnerability
- Dash Strike is reachable from a roll
- Two enemies engage from opposite sides rather than the same one
- A telegraphed attack has a readable wind-up before its hitbox activates

# Roadmap

## Phase 1 — Playable vertical slice ✅ **done (v0.1.0)**

Every system the full game needs, proved end to end on five connected areas.

- Data-driven combat: 39 moves, combo chains, grabs, throws, weapons, a special
- Six enemy archetypes with spacing-aware AI, plus an encounter director
- Money, XP, six stats, nine permanent bonuses
- Five shop types, 13 foods, 8 books, 7 purchasable techniques
- Quests, dialogue with portraits and choices, 10+ NPCs
- Five connected areas built from data, a two-phase boss
- Versioned save/load that works in the browser
- Multitouch mobile controls, a deployed web build
- 107 automated checks, a screenshot harness, full documentation

---

## Phase 2 — Expanded city

Prove the "content, not code" claim by adding a district without touching the engine.

- Three to four new areas beyond the metro gate: the metro platform, a rooftop route, a
  riverside market, a residential block
- A second district hub with its own shops
- Fast travel between visited areas, using `AreaData.connections`
- A proper map screen with the connection graph drawn, not a list
- Interiors that are real rooms rather than shopfronts

## Phase 3 — More gangs

- Two or three new crews with their own colours, taunts and defeat lines
- Two new archetypes: a shielder who has to be flanked, and a duo who fight better together
- Gang reputation, so clearing a block changes who greets you and who crosses the street
- Mini-bosses per gang, using the boss phase system already in `Boss.gd`

## Phase 4 — More shops

- Clothing, with cosmetic changes that stack small stat bonuses (`ShopData.CLOTHING`
  already exists)
- A pawn shop that buys weapons back
- A second dojo teaching a different school, so builds diverge
- Shop stock that changes with story progress
- Prices that respond to gang control of a block

## Phase 5 — Character progression expansion

- Two more playable characters with different rigs and move sets. `MoveData` and
  `PlayerState` already support this; it needs a character-select and per-character move
  lists.
- Move upgrades: buy a technique, then improve it
- A light skill tree branching from Strength, Technique and Speed
- Equipment slots beyond the carried weapon

## Phase 6 — Story campaign

- Chapters two and three: who sends the Tuesday money, and why a laundromat
- Cutscene support beyond dialogue: scripted camera moves and actor blocking
- Branching choices that set world flags and change endings
- Optional side stories per NPC

## Phase 7 — Boss expansion

- One boss per gang, each with a distinct mechanic rather than a distinct stat block
- Three-phase fights for late bosses
- A boss rush unlocked after the campaign
- Arena hazards that both sides have to respect

## Phase 8 — Polish

- Hand-tuned animation passes on the most-seen moves
- Weather and time of day, using the existing parallax tinting
- Screen-space effects: a subtle CRT option, hit vignettes
- Haptics on mobile
- Full controller remapping
- Localisation, which the abstract signage was designed to allow

## Phase 9 — Alpha testing

- Difficulty options
- Telemetry on where players die and what they buy
- Balance passes driven by that data
- Accessibility: hold-to-run toggle, screen shake slider, colourblind-safe enemy tells
- Save slots in the UI (`SaveManager` already supports three)

## Phase 10 — Release preparation

- Desktop exports for Windows, macOS and Linux
- Steam and itch.io packaging
- Achievements
- A trailer and store assets
- Final performance pass on low-end mobile

---

## What Phase 1 deliberately left out

Called out so nobody mistakes them for oversights:

- **Enemy flanking.** Enemies circle and space themselves but do not coordinate a pincer.
- **Multiple save slots in the UI.** The backend supports three; the menu uses one.
- **A second playable character.** The systems allow it; no content exists.
- **Cutscenes.** Story is told through dialogue only.
- **Difficulty options.** One curve, tuned for a first playthrough.

# World structure

Riverbend is a connected city, not a stage select. You walk off the edge of one street and
onto the next.

```
Ferry Row ──► Lantern Market ──► Grease Alley ──► Rustpile Yard ──► Starch & Sons
 (river)        (shops)           (weapons)         (heavies)          (boss)
   1500px         1600px            1400px            1500px            1000px
```

Every connection is two-way except the last: the laundromat door only opens once the yard
is clear.

---

## The areas

### 1. Ferry Row — *Riverbend East*

Where the river meets the city. Ferry horns, fried dough, and a gang named after birds.

Teaches everything: walking, the combo chain, money bouncing onto the pavement, talking to
people, and breaking a trash can to find out that trash cans are worth breaking.

- **Gang:** the Pigeons. Grunts, then a rusher, then a squad of five.
- **NPCs:** Dez (the friend who called you back), the ferry operator, a street performer,
  a dock worker, a local.
- **Notable:** the first quest, a bottle and a plank lying around, a vending machine that
  takes your money and gives you a look.

### 2. Lantern Market — *Riverbend East*

Two blocks of food stalls, secondhand books and a dojo nobody can find twice. Every shop in
the game is here.

- **Gang:** the Sweaters. A shakedown mid-street, plus an optional fight at the far end.
- **Shops:** Mae's Noodle Counter, Vic's Corner Store, Marisol's Stacks, Odell's Back Room
  Dojo, and Pops' gear (later, in the alley).
- **NPCs:** Auntie Mae, Vic, Marisol, Odell, a student who lost his backpack, a kid with a
  rumour about a laundromat.
- **Notable:** a dojo flyer in a trash can, a crate with a pipe in it, a bat on the ground.

### 3. Grease Alley — *Backstreets*

Narrow, damp, full of useful objects and people who resent you finding them. Where weapons
start to matter.

- **Gang:** the Grease Monkeys. An ambush, then a larger fight with a borrowed grappler.
- **NPC:** Pops, who sells gear once he decides he likes you.
- **Notable:** the stolen backpack in a crate, a chair, a brick, two bats, a note taped
  inside a dumpster lid mentioning a Tuesday route.

### 4. Rustpile Yard — *Industrial*

A scrapyard nobody is scrapping. The fence is new, which is the strange part.

- **Gang:** the Rust Rats. Throwers first, then a Girder with support.
- **Notable:** the widest mix of archetypes at once, a whole trash can usable as a weapon,
  and the door to the laundromat, locked until the yard is clear.

### 5. Starch & Sons — *Industrial*

Interior. Always open, always empty, always immaculate.

- **Gang:** the Cleaners. Two waves of elites, then Big Starch.
- **Notable:** an attendant who insists the shop is closed while the sign says open, mops
  and a chair to fight with, and the only boss in the slice.

---

## How an area is built

There is no per-area scene. `Area.gd` reads `data/areas/<id>.json` and constructs the
street at runtime:

| Section | Becomes |
|---|---|
| `parallax` | Scrolling background layers, each with its own scroll factor |
| `ground` | Repeating 16 px tile strips from one atlas |
| `scenery` | Flat sprites: buildings, awnings, graffiti, cars, fences |
| `props` | Interactive objects: solid, breakable, searchable, or decorative |
| `weapons` | Weapons lying on the ground |
| `npcs` | Characters with dialogue, shops and conditional lines |
| `doors` | Travel points and shop entrances |
| `spawns` | Named entry positions |
| `encounters` | Positional triggers that hand an encounter to the director |

`AreaData` resources carry the display name, district, music, ambience, gang and map
position, kept separate so the map screen and menus can read them without loading a street.

---

## Vertical layout

y grows downward and doubles as lane depth, which is what drives Y-sorting.

```
 -46  road            parked cars, fences, the back of the scene
   2  building base   buildings stand on this line
  18  sidewalk top    tiles begin
  34  LANE_MIN        back of the walkable lane
  74  LANE_MAX        front of the walkable lane
 130  sidewalk end
 -12  camera centre
```

A character at y=34 is further into the screen than one at y=74 and draws behind them. Props
sit at their own lane y and sort with the fighters, so you can walk in front of a bench and
behind a phone booth.

---

## Travel

Street-edge doors are marked `auto`, so walking into one travels. Shop doors and interior
entrances need an interact press, and show a prompt when you are near.

Each door names a destination area and a **spawn id**, so arriving from the west puts you at
the west entrance. Some doors carry a `required_flag`, which is how the laundromat stays
shut until the yard is cleared, with an in-character message rather than a locked-door beep.

Travel goes through `SceneManager.change_area()`: fade out, tear down the old area, build
the new one, place the player at the named spawn, fade in.

---

## Encounters

Encounters are positional. Walking within range of a trigger hands its `EncounterData` to
the area's `EnemyDirector`, which:

- spawns waves from off-screen up to a cap (usually three or four at once),
- sends reinforcements as the crowd thins,
- locks the camera so the fight has edges,
- switches music if the encounter specifies it,
- and reports when the last enemy is down.

A cleared encounter can set a world flag, which is how "clear the yard" opens the door to
the laundromat. Most encounters respawn on re-entry so the streets stay dangerous; story
fights are marked `once_flag` and stay cleared.

---

## Adding an area

1. Add an `AreaData` entry in `tools/gen_data.py` (name, district, music, ambience, map
   position, connections).
2. Add a layout block in `tools/gen_areas.py`.
3. Add doors in the neighbouring areas pointing at it, and doors in it pointing back.
4. Add any new encounters, enemies, NPCs and dialogue in `gen_data.py`.
5. Run both generators, then the smoke test, which verifies every reference resolves and
   that the camera can frame the player at both ends of the new street.

No new scenes, no new scripts.

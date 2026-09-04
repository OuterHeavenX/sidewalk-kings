# Game design

## Premise

Kip comes home to Riverbend after two years away. Four blocks, four crews: the Pigeons on
Ferry Row, the Sweaters in Lantern Market, the Grease Monkeys in the alley, the Rust Rats
in the yard.

The strange part is not that gangs run the blocks. It is that they have stopped fighting
each other. Last month they simply agreed on a map and kept to it.

> **Kip:** Gangs don't agree.
> **Dez:** Gangs don't agree *for free*.

Following the money leads through four neighbourhoods to a laundromat that is always open
and never has any customers. Big Starch pays four crews to be tidy. He is not the top of
the chain, and he says so on the way down: the money arrives on Tuesdays, in a bag, from
the metro side, carried by someone who never gets off the train.

That is where chapter one ends. The metro gate is chained and laminated, which is a
promise rather than a wall.

## Tone

Energetic, funny, and warmer than it first looks. The comedy is in how ordinary everyone
is: a student more worried about his sandwich than his textbooks, a ferry operator who has
been on shift since Tuesday, a shopkeeper who defends the neighbourhood with soup.

The seriousness underneath is structural rather than grim. Somebody is organising this
city, and the joke is that they are doing it through a laundromat.

> **Enemy:** You picked the wrong alley.
> **Kip:** There were two alleys.
> **Enemy:** ...you picked the worse one.

Not every line is a joke. NPC dialogue carries most of the world-building, and some of it
is just a person telling you the ferry has been running on time for the first time in years
and finding that unsettling.

---

## The loop

```
explore a street → run into a gang → fight → collect money and XP
   → spend money on food, training, books and gear
   → come back stronger → push into the next block
```

Money is the spine. Enemies drop physical cash that bounces onto the pavement and is picked
up by walking over it. Everything that makes you stronger costs money, so a fight you barely
survived becomes the reason you can afford the technique that makes the next one easy.

XP raises your level, which raises baseline stats. But most growth is bought, not earned:
food gives permanent stat points, books give bonuses and unlock moves, the dojo sells
techniques. That is deliberate. Levelling should feel like a floor, and shopping should feel
like the actual build.

---

## Progression

**Six stats**

| Stat | What it does |
|---|---|
| Strength | Punch, kick and throw damage |
| Defense | Reduces incoming damage |
| Speed | Movement speed |
| Stamina | Max HP, max energy, energy regeneration |
| Technique | Crit chance, throw damage, special damage |
| Luck | Crit chance, and how much money enemies drop |

**Nine permanent bonuses** sit on top: punch damage, kick damage, throw damage, max HP,
move speed, weapon skill, special damage, stamina recovery, and crit chance. They come from
books, food and quest rewards, and are the difference between a level 5 who has been eating
and reading and one who has not.

**Levelling** gives +1 Strength and +1 Stamina every level, +1 Defense and Speed on even
levels, +1 Technique and Luck every third. Enough to matter, not enough to carry you.

---

## Sources of power

| Source | Gives |
|---|---|
| Defeating enemies | XP and money |
| Restaurants | Health, plus permanent stat points on the better dishes |
| Convenience stores | Cheap healing and carryable snacks |
| The dojo | Seven purchasable techniques with level and stat requirements |
| The bookstore | Eight books: stat points, bonuses, and one unlockable throw |
| The weapon shop | Weapons you can carry between areas |
| Quests | Money, XP, items, and one free technique |
| Breakable props | Money, food and hidden weapons |

The dojo gates deliberately. The Power Punch needs level 5, Strength 12 and the Haymaker
already learned, so it reads as the end of a line of investment rather than a purchase.

---

## The gangs

| Gang | Block | Character |
|---|---|---|
| **The Pigeons** | Ferry Row | Loud, soft, territorial about a queue. The tutorial gang. |
| **The Sweaters** | Lantern Market | Politely extortionate. Ask for "a contribution to the neighbourhood". |
| **The Grease Monkeys** | Grease Alley | Have tools and use them. Where weapons start mattering. |
| **The Rust Rats** | Rustpile Yard | Fenced off a scrapyard nobody is scrapping. Heavies and throwers. |
| **The Cleaners** | Starch & Sons | Immaculate, unhurried, work for the boss. |

Each gang is a set of `EnemyData` resources sharing a `gang` id, which is what quest
objectives like "defeat 5 Pigeons" count against.

---

## Enemy archetypes

| Archetype | Behaviour |
|---|---|
| **Grunt** | Approaches, keeps a fighting distance, jabs and kicks. |
| **Rusher** | Fast, aggressive, closes hard, low health. |
| **Grappler** | Heavy, seeks grabs, hard to throw. |
| **Weapon user** | Detours to pick up anything on the ground. |
| **Heavy** | Slow, armored against light hits, cannot be grabbed, hits enormously. |
| **Ranged** | Keeps distance and throws things; retreats when you close. |
| **Boss** | Two phases, a telegraphed heavy, and a dedicated health bar. |

They do not walk in a straight line into your fists. Each has a preferred distance, a
reaction delay, an attack cooldown and a chance to circle instead of committing, and they
push apart from each other so a group actually surrounds you.

---

## The boss

**Big Starch** runs Starch & Sons. He is enormous, dressed entirely in white, and deeply
offended that you have tracked half the river across his floor.

- **Phase one.** 340 base HP, armored against light hits, cannot be grabbed. Every few
  seconds he winds up a Pressing Slam with a visible flash and a long tell. It covers a
  wide area and knocks down. The phase is about learning to read it.
- **Phase two**, below half health. Faster, shorter cooldowns, more aggressive, and he
  adds a charging Laundry Run from across the room. He also becomes grabbable, so the
  fight opens up exactly as it gets harder.

He is defeated, not killed, and he talks. That is where the chapter hook lands.

---

## The city

| Area | Purpose |
|---|---|
| **Ferry Row** | Teaches movement, the combo chain, money, and talking to people. |
| **Lantern Market** | All five shops, most NPCs, the first optional fight. |
| **Grease Alley** | Weapons and breakable objects. A hidden note. Tighter fights. |
| **Rustpile Yard** | Mixed archetypes at once. Heavies and throwers together. |
| **Starch & Sons** | Interior. Elites, then the boss. |

Areas connect by walking off the edge of the street, so the city is continuous rather than
a stage select. Doors into shops are the same system with a shop id instead of a
destination.

---

## Quests

Eight, two of them required:

| Quest | Type |
|---|---|
| Clear the Ferry Row | Defeat 5 Pigeons (required) |
| The Very Heavy Backpack | Recover a stolen item from the alley |
| Free First Lesson | Find a dojo flyer; rewards a technique |
| Soup Delivery | Carry Furnace Soup across two areas before it cools (it does not cool) |
| Whoever Runs the Alley | Clear Grease Alley (required) |
| Rust and Trouble | Defeat 6 Rust Rats |
| Big Starch | Defeat the boss (required) |
| Feed the Ferry Man | Bring a rice ball to someone who has not eaten since Tuesday |

Quests track themselves off `EventBus` signals, so an objective completes the moment its
condition is met rather than on a re-check.

---

## Food

Thirteen items, and the descriptions are half the point.

| Item | Effect |
|---|---|
| Bowl of Hot Noodles | +55 HP, +1 Stamina, +3 Max HP |
| Furnace Soup | +60 HP, +1 Defense, +4 Max HP. "So hot it is legally a hazard." |
| Steelworker's Lunch | +75 HP, +1 Strength, +1 Stamina, +6 Max HP |
| Amp Fizz | +40 energy, +1 Speed. "Tastes like a battery that went to art school." |
| Yesterday's Noodles | +20 HP. "Texture: bold." |
| Day-Old Donut | +12 HP. "The glaze has fused into a protective shell." |
| Mystery Skewer | +30 HP, +1 Strength. "Three cubes of something, grilled with confidence." |

Sit-down food at the restaurant is eaten on the spot. Takeout goes into your inventory and
can be eaten from the pause menu mid-fight, which is the closest thing to a healing item.

---

## Design priorities

In order, when something had to give:

1. The game launches and keeps running.
2. Movement feels immediate.
3. Hits feel physical.
4. Enemies behave like fighters, not obstacles.
5. The city connects.
6. Saves survive a reload.
7. Touch controls work.
8. Shops and progression matter.
9. The boss fight is a fight.
10. Visual polish.
11. More content.

---

## What chapter two would open with

The hooks are already planted:

- The metro gate is chained and the sign is laminated.
- Money arrives on Tuesdays from the metro side.
- Someone brings it who never gets off the train.
- Big Starch was given a *route*, not a job.

`AreaData.connections` and the map screen already accommodate more districts, and the
existing content types cover everything a new neighbourhood needs.

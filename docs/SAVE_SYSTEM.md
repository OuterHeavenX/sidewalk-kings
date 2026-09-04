# Save system

Saves are versioned JSON written to `user://`, which works unchanged on desktop and in the
browser.

---

## Where saves live

| Target | Location |
|---|---|
| Windows | `%APPDATA%\Godot\app_userdata\Sidewalk Kings\saves\slot_0.json` |
| macOS | `~/Library/Application Support/Godot/app_userdata/Sidewalk Kings/saves/` |
| Linux | `~/.local/share/godot/app_userdata/Sidewalk Kings/saves/` |
| Web | IndexedDB, per origin |

Settings are separate, in `user://settings.json`, so audio volumes survive starting a new
game.

`SaveManager` only ever touches `user://`. It never builds an absolute path and never
assumes a real filesystem, which is what lets the same code work in a browser.

---

## What is saved

Everything persistent lives on `PlayerState`, which serialises in one call:

```
player_name, level, xp, money, hp, energy, special
stats            strength, defense, speed, stamina, technique, luck
bonuses          punch_damage, kick_damage, throw_damage, max_hp, move_speed,
                 weapon_skill, special_damage, stamina_recovery, crit_chance
known_moves      every technique learned
inventory        item id -> count
key_items        quest items
books_read       which books have been read
purchases        "shop_id/item_id" -> count
flags            every world flag
quests           quest id -> {state, progress}
bosses_defeated  boss ids
current_area     where to resume
current_spawn    which entrance to resume at
playtime         seconds
equipped_weapon  what you were carrying
```

The file also records `save_version`, the game version, and a timestamp.

Keeping all of this on a plain `RefCounted` rather than spread across nodes is the reason
saving, loading and starting a new game are each a single operation.

---

## Format

```json
{
  "save_version": 1,
  "game_version": "0.1.0",
  "timestamp": "2026-09-04T13:46:50",
  "player": {
    "level": 7,
    "money": 1234,
    "stats": { "strength": 9, "defense": 7, "...": 0 },
    "known_moves": ["punch_1", "punch_2", "uppercut"],
    "flags": { "market_cleared": true },
    "quests": { "q_pigeons": { "state": "done", "progress": 5 } },
    "current_area": "grease_alley"
  }
}
```

Human-readable on purpose. A broken save can be inspected, and a tester can edit one.

---

## Versioning and migration

Every save carries `save_version`, currently `1`. `SaveManager.migrate()` walks a file
forward one version at a time:

```gdscript
func migrate(data: Dictionary) -> Dictionary:
    var v := int(data.get("save_version", 0))
    while v < SAVE_VERSION:
        match v:
            0:
                # Pre-versioned saves stored the player dictionary at the top level.
                if not data.has("player"):
                    data = {"player": data}
                v = 1
            _:
                v += 1
        data["save_version"] = v
    return data
```

To add version 2: bump `SAVE_VERSION`, add a `1:` branch that transforms a v1 file into a
v2 one, and leave the v0 branch alone. Old saves then walk 0 → 1 → 2.

Loading is also defensive on its own. `PlayerState.from_dict()` resets to defaults first
and reads every field with a fallback, so a save missing a key added later still loads.

---

## When saving happens

Saving is manual, from **Pause → Save**. Nothing autosaves.

Before writing, `SaveManager` calls `Player.sync_to_data()` so live HP, energy, special
meter and the carried weapon are captured. Money, XP, flags, items and quests are already
written straight to `PlayerState` as they change, so they are always current.

On load, `SceneManager.continue_game()` replaces `GameManager.player_data`, switches to the
gameplay scene, and `Game.load_area()` builds the saved area and drops the player at the
saved spawn point.

---

## Death

Dying is not a game over. You lose a quarter of your money, wake up at the area entrance
with 60% health, and the area's encounters reset. It costs you progress toward the next
purchase rather than progress through the game.

---

## Failure handling

- A missing file returns cleanly and the title screen simply does not offer **Continue**.
- Malformed JSON is caught, logged, and reported through `SaveManager.last_error`.
- A failed write surfaces as an on-screen notification rather than failing silently.
- Loading clamps HP and energy to the current maxima, so a save edited by hand cannot
  produce an invalid character.

---

## Tested

The smoke test (`godot --headless --path . -- --smoke`) covers:

- writing a save and reading its summary back
- clearing state with a new game, then restoring the save
- restoring level, money, learned moves, world flags, inventory counts and the current area
- migrating a pre-versioned save dictionary to the current schema

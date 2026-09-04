class_name PlayerState
extends RefCounted
## All persistent player data. Serialisable to a dictionary for SaveManager.

const STAT_NAMES := ["strength", "defense", "speed", "stamina", "technique", "luck"]
const BONUS_NAMES := ["punch_damage", "kick_damage", "throw_damage", "max_hp", "move_speed",
	"weapon_skill", "special_damage", "stamina_recovery", "crit_chance"]
const STARTING_MOVES := ["punch_1", "punch_2", "punch_3", "kick", "heavy", "jump_kick",
	"run_attack", "grab", "throw", "grab_punch", "ground_stomp", "special_burst"]

var player_name: String = "Kip"
var level: int = 1
var xp: int = 0
var money: int = 0
var hp: int = 0
var energy: float = 0.0
var special: float = 0.0
var stats: Dictionary = {}
var bonuses: Dictionary = {}
var known_moves: Array[String] = []
var inventory: Dictionary = {}       # item_id -> count
var key_items: Array[String] = []
var books_read: Array[String] = []
var purchases: Dictionary = {}       # "shop_id/item_id" -> count
var flags: Dictionary = {}
var quests: Dictionary = {}          # quest_id -> {state, progress}
var bosses_defeated: Array[String] = []
var current_area: String = "ferry_row"
var current_spawn: String = "start"
var playtime: float = 0.0
var equipped_weapon: String = ""

func _init() -> void:
	reset()

func reset() -> void:
	level = 1
	xp = 0
	money = 40
	stats = {}
	bonuses = {}
	for s in STAT_NAMES:
		stats[s] = 5
	for b in BONUS_NAMES:
		bonuses[b] = 0
	known_moves.assign(STARTING_MOVES)
	inventory = {}
	key_items = []
	books_read = []
	purchases = {}
	flags = {}
	quests = {}
	bosses_defeated = []
	current_area = "ferry_row"
	current_spawn = "start"
	playtime = 0.0
	equipped_weapon = ""
	hp = get_max_hp()
	energy = get_max_energy()
	special = 0.0

# ---- Derived attributes ----
func get_max_hp() -> int:
	return 60 + int(stats.stamina) * 4 + level * 6 + int(bonuses.max_hp)

func get_max_energy() -> float:
	return 40.0 + float(stats.stamina) * 2.0

func get_move_speed() -> float:
	return 105.0 + float(stats.speed) * 2.5 + float(bonuses.move_speed)

func get_punch_multiplier() -> float:
	return 1.0 + stats.strength * 0.05 + bonuses.punch_damage * 0.05

func get_kick_multiplier() -> float:
	return 1.0 + stats.strength * 0.05 + bonuses.kick_damage * 0.05

func get_throw_multiplier() -> float:
	return 1.0 + stats.strength * 0.04 + stats.technique * 0.03 + bonuses.throw_damage * 0.05

func get_weapon_multiplier() -> float:
	return 1.0 + stats.strength * 0.03 + bonuses.weapon_skill * 0.08

func get_special_multiplier() -> float:
	return 1.0 + stats.technique * 0.05 + bonuses.special_damage * 0.08

func get_defense_reduction() -> float:
	return 100.0 / (100.0 + float(stats.defense) * 4.0)

func get_crit_chance() -> float:
	return clampf(0.03 + stats.technique * 0.01 + stats.luck * 0.005 + bonuses.crit_chance * 0.02, 0.0, 0.6)

func get_energy_regen() -> float:
	return 6.0 + stats.stamina * 0.4 + bonuses.stamina_recovery * 1.5

func get_luck_money_multiplier() -> float:
	return 1.0 + float(stats.luck) * 0.03

func xp_to_next_level() -> int:
	return 40 + (level - 1) * (level - 1) * 12 + (level - 1) * 30

# ---- Serialisation ----
func to_dict() -> Dictionary:
	return {
		"player_name": player_name,
		"level": level, "xp": xp, "money": money, "hp": hp, "energy": energy, "special": special,
		"stats": stats.duplicate(), "bonuses": bonuses.duplicate(),
		"known_moves": Array(known_moves), "inventory": inventory.duplicate(),
		"key_items": Array(key_items), "books_read": Array(books_read),
		"purchases": purchases.duplicate(), "flags": flags.duplicate(), "quests": quests.duplicate(true),
		"bosses_defeated": Array(bosses_defeated), "current_area": current_area,
		"current_spawn": current_spawn, "playtime": playtime, "equipped_weapon": equipped_weapon,
	}

func from_dict(d: Dictionary) -> void:
	reset()
	player_name = str(d.get("player_name", player_name))
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	money = int(d.get("money", 0))
	var dstats: Dictionary = d.get("stats", {})
	var dbon: Dictionary = d.get("bonuses", {})
	for s in STAT_NAMES:
		stats[s] = int(dstats.get(s, 5))
	for b in BONUS_NAMES:
		bonuses[b] = int(dbon.get(b, 0))
	known_moves.assign(_to_string_array(d.get("known_moves", STARTING_MOVES)))
	inventory = Dictionary(d.get("inventory", {})).duplicate()
	key_items.assign(_to_string_array(d.get("key_items", [])))
	books_read.assign(_to_string_array(d.get("books_read", [])))
	purchases = Dictionary(d.get("purchases", {})).duplicate()
	flags = Dictionary(d.get("flags", {})).duplicate()
	quests = Dictionary(d.get("quests", {})).duplicate(true)
	bosses_defeated.assign(_to_string_array(d.get("bosses_defeated", [])))
	current_area = str(d.get("current_area", "ferry_row"))
	current_spawn = str(d.get("current_spawn", "start"))
	playtime = float(d.get("playtime", 0.0))
	equipped_weapon = str(d.get("equipped_weapon", ""))
	hp = clampi(int(d.get("hp", get_max_hp())), 1, get_max_hp())
	energy = clampf(float(d.get("energy", get_max_energy())), 0.0, get_max_energy())
	special = clampf(float(d.get("special", 0.0)), 0.0, 100.0)

static func _to_string_array(a: Variant) -> Array[String]:
	var out: Array[String] = []
	if a is Array:
		for v in a:
			out.append(str(v))
	return out

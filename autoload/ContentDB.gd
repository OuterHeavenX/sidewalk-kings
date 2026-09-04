extends Node
## Loads every data resource (moves, enemies, food, items, weapons, shops, quests, dialogue, encounters)
## from res://data/** at startup and exposes them by id. Content lives in data, not code.

var moves: Dictionary = {}
var enemies: Dictionary = {}
var foods: Dictionary = {}
var items: Dictionary = {}
var weapons: Dictionary = {}
var shops: Dictionary = {}
var quests: Dictionary = {}
var dialogues: Dictionary = {}
var encounters: Dictionary = {}
var books: Dictionary = {}
var areas: Dictionary = {}

func _ready() -> void:
	reload_all()

func reload_all() -> void:
	moves = _load_dir("res://data/moves/")
	enemies = _load_dir("res://data/enemies/")
	foods = _load_dir("res://data/food/")
	items = _load_dir("res://data/items/")
	weapons = _load_dir("res://data/weapons/")
	shops = _load_dir("res://data/shops/")
	quests = _load_dir("res://data/quests/")
	dialogues = _load_dir("res://data/dialogue/")
	encounters = _load_dir("res://data/encounters/")
	books = _load_dir("res://data/books/")
	areas = _load_dir("res://data/areas/")
	print("[ContentDB] moves=%d enemies=%d foods=%d items=%d weapons=%d shops=%d quests=%d dialogues=%d encounters=%d books=%d areas=%d" % [
		moves.size(), enemies.size(), foods.size(), items.size(), weapons.size(), shops.size(),
		quests.size(), dialogues.size(), encounters.size(), books.size(), areas.size()])

func _load_dir(path: String) -> Dictionary:
	var out := {}
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var clean := fname
			# Exported projects list .remap files for imported resources.
			if clean.ends_with(".remap"):
				clean = clean.trim_suffix(".remap")
			if clean.ends_with(".tres") or clean.ends_with(".res"):
				var res := load(path + clean)
				if res != null:
					var id: String = res.get("id") if res.get("id") != null and str(res.get("id")) != "" else clean.get_basename()
					out[id] = res
		fname = dir.get_next()
	dir.list_dir_end()
	return out

func get_move(id: String) -> Resource:
	return moves.get(id)

func get_enemy(id: String) -> Resource:
	return enemies.get(id)

func get_food(id: String) -> Resource:
	return foods.get(id)

func get_item(id: String) -> Resource:
	if items.has(id):
		return items[id]
	if foods.has(id):
		return foods[id]
	if books.has(id):
		return books[id]
	return null

func get_weapon(id: String) -> Resource:
	return weapons.get(id)

func get_shop(id: String) -> Resource:
	return shops.get(id)

func get_quest(id: String) -> Resource:
	return quests.get(id)

func get_dialogue(id: String) -> Resource:
	return dialogues.get(id)

func get_encounter(id: String) -> Resource:
	return encounters.get(id)

func get_book(id: String) -> Resource:
	return books.get(id)

func get_area(id: String) -> Resource:
	return areas.get(id)

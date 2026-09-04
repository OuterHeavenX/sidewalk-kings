extends Node
## Opens the reusable ShopController UI for any ShopData and handles purchases.

const SHOP_SCENE := "res://ui/shops/ShopController.tscn"

var _ui: Node = null
var current_shop: ShopData = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ensure_ui() -> void:
	if _ui != null and is_instance_valid(_ui):
		return
	if not ResourceLoader.exists(SHOP_SCENE):
		push_error("[ShopManager] Missing ShopController scene")
		return
	_ui = load(SHOP_SCENE).instantiate()
	_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_ui)
	_ui.closed.connect(_on_closed)

func is_open() -> bool:
	return current_shop != null

func open_shop(shop_id: String) -> void:
	if current_shop != null:
		return
	var shop: ShopData = ContentDB.get_shop(shop_id)
	if shop == null:
		push_warning("[ShopManager] Unknown shop %s" % shop_id)
		return
	_ensure_ui()
	if _ui == null:
		return
	current_shop = shop
	GameManager.set_state(GameManager.State.SHOP)
	EventBus.shop_opened.emit(shop_id)
	_ui.open(shop)

func _on_closed() -> void:
	var id := current_shop.id if current_shop else ""
	current_shop = null
	if GameManager.state == GameManager.State.SHOP:
		GameManager.set_state(GameManager.State.PLAYING)
	EventBus.shop_closed.emit(id)

## Returns a list of dictionaries describing purchasable entries for the UI.
func build_entries(shop: ShopData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item_id in shop.inventory:
		var e := describe_entry(shop, item_id)
		if not e.is_empty():
			out.append(e)
	return out

func describe_entry(shop: ShopData, item_id: String) -> Dictionary:
	var pd := GameManager.player_data
	match shop.shop_type:
		ShopData.ShopType.DOJO:
			var m: MoveData = ContentDB.get_move(item_id)
			if m == null:
				return {}
			var owned := GameManager.has_move(item_id)
			var reqs: PackedStringArray = []
			var locked := false
			if m.required_level > pd.level:
				reqs.append("Lv %d" % m.required_level); locked = true
			if m.required_stat != "" and int(pd.stats.get(m.required_stat, 0)) < m.required_stat_value:
				reqs.append("%s %d" % [m.required_stat.substr(0, 3).to_upper(), m.required_stat_value]); locked = true
			if m.required_move != "" and not GameManager.has_move(m.required_move):
				var rm: MoveData = ContentDB.get_move(m.required_move)
				reqs.append("Know %s" % (rm.display_name if rm else m.required_move)); locked = true
			if m.required_flag != "" and not GameManager.get_flag(m.required_flag):
				reqs.append("Story"); locked = true
			return {"id": item_id, "name": m.display_name, "price": m.price, "desc": m.description,
				"detail": _move_detail(m), "owned": owned, "locked": locked, "requirements": ", ".join(reqs), "kind": "move"}
		ShopData.ShopType.BOOKS:
			var b: BookData = ContentDB.get_book(item_id)
			if b == null:
				return {}
			var owned := item_id in pd.books_read
			var locked := b.required_level > pd.level
			return {"id": item_id, "name": b.display_name, "price": b.price, "desc": b.description,
				"detail": b.blurb, "owned": owned, "locked": locked,
				"requirements": ("Lv %d" % b.required_level) if locked else "", "kind": "book"}
		ShopData.ShopType.WEAPONS:
			var w: WeaponData = ContentDB.get_weapon(item_id)
			if w == null:
				return {}
			return {"id": item_id, "name": w.display_name, "price": w.shop_price, "desc": "Damage %d. %s" % [w.damage, ("Breaks after %d hits." % w.durability) if w.breaks else "Sturdy."],
				"detail": "", "owned": false, "locked": false, "requirements": "", "kind": "weapon"}
		_:
			var f: FoodData = ContentDB.get_food(item_id)
			if f != null:
				return {"id": item_id, "name": f.display_name, "price": f.price, "desc": f.description,
					"detail": f.stat_summary(), "owned": false, "locked": false, "requirements": "", "kind": "food"}
			var it: ItemData = ContentDB.get_item(item_id)
			if it != null and it is ItemData:
				return {"id": item_id, "name": it.display_name, "price": it.price, "desc": it.description,
					"detail": ("+%d HP" % it.heal) if it.heal > 0 else "", "owned": false, "locked": false, "requirements": "", "kind": "item"}
	return {}

func _move_detail(m: MoveData) -> String:
	return "DMG %d  %s" % [m.damage, ["Light", "Heavy", "Special", "Jump", "Grab"][clampi(m.input - 1, 0, 4)] if m.input > 0 else ""]

## Attempt to buy. Returns a status string for the UI: "ok", "broke", "owned", "locked", "full".
func purchase(shop: ShopData, entry: Dictionary) -> String:
	var pd := GameManager.player_data
	if entry.get("owned", false):
		return "owned"
	if entry.get("locked", false):
		return "locked"
	var price := int(entry.get("price", 0))
	if pd.money < price:
		return "broke"
	var id := str(entry["id"])
	match str(entry["kind"]):
		"move":
			GameManager.spend_money(price)
			GameManager.unlock_move(id)
		"book":
			GameManager.spend_money(price)
			var b: BookData = ContentDB.get_book(id)
			pd.books_read.append(id)
			if b.unlock_move != "":
				GameManager.unlock_move(b.unlock_move)
			if b.stat != "" and b.stat_bonus != 0:
				GameManager.add_stat(b.stat, b.stat_bonus)
			if b.bonus != "" and b.bonus_amount != 0:
				GameManager.add_bonus(b.bonus, b.bonus_amount)
		"food":
			var f: FoodData = ContentDB.get_food(id)
			if f.takeout:
				GameManager.spend_money(price)
				GameManager.add_item(id, 1)
			else:
				GameManager.spend_money(price)
				apply_food(f)
		"item":
			GameManager.spend_money(price)
			GameManager.add_item(id, 1)
		"weapon":
			if is_instance_valid(GameManager.player) and GameManager.player.has_method("give_weapon"):
				if not GameManager.player.give_weapon(id):
					return "full"
			GameManager.spend_money(price)
	var key := "%s/%s" % [shop.id, id]
	pd.purchases[key] = int(pd.purchases.get(key, 0)) + 1
	EventBus.shop_purchase.emit(shop.id, id, price)
	AudioManager.play_ui("purchase")
	return "ok"

## Eating food: heals and applies permanent bonuses. Used by shops and inventory.
func apply_food(f: FoodData) -> void:
	if f.heal > 0:
		GameManager.heal_player(f.heal)
	if f.energy > 0 and is_instance_valid(GameManager.player) and GameManager.player.has_method("restore_energy"):
		GameManager.player.restore_energy(f.energy)
	if f.strength_bonus: GameManager.add_stat("strength", f.strength_bonus)
	if f.defense_bonus: GameManager.add_stat("defense", f.defense_bonus)
	if f.speed_bonus: GameManager.add_stat("speed", f.speed_bonus)
	if f.stamina_bonus: GameManager.add_stat("stamina", f.stamina_bonus)
	if f.technique_bonus: GameManager.add_stat("technique", f.technique_bonus)
	if f.luck_bonus: GameManager.add_stat("luck", f.luck_bonus)
	if f.max_hp_bonus: GameManager.add_bonus("max_hp", f.max_hp_bonus)
	var summary := f.stat_summary()
	GameManager.notify("%s: %s" % [f.display_name, summary if summary != "" else "yum"], "food")

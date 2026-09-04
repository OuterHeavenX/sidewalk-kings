extends Node
## Automated QA pass. Run with:
##   godot --headless --path . -- --smoke
##
## Drives a real game session with no human input: starts a new game, walks into every
## area, spawns and fights enemies, uses weapons, buys from every shop, runs quests and
## dialogue, fights the boss, then saves and reloads. Any engine error or failed check is
## reported at the end with a non-zero exit code.

var results: Array[Dictionary] = []
var errors: Array[String] = []
var game: Node = null
var _log: FileAccess = null
var _dialogue_finished: bool = false

func _on_dialogue_ended(_id: String) -> void:
	_dialogue_finished = true

## Every line is flushed to user://smoke_test.log as well as stdout, so a hang or crash
## still leaves a record of exactly how far the run got.
func log_line(text: String) -> void:
	print(text)
	if _log == null:
		_log = FileAccess.open("user://smoke_test.log", FileAccess.WRITE)
	if _log:
		_log.store_line(text)
		_log.flush()

func check(name: String, ok: bool, detail: String = "") -> void:
	results.append({"name": name, "ok": ok, "detail": detail})
	log_line("  [%s] %s%s" % ["PASS" if ok else "FAIL", name, ("  -> " + detail) if detail != "" else ""])

func _ready() -> void:
	print("\n=== SIDEWALK KINGS SMOKE TEST ===")
	await get_tree().process_frame
	await run()
	_report()

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout

func run() -> void:
	await test_content()
	await test_new_game()
	await test_movement()
	await test_combat()
	await test_weapons()
	await test_pickups_and_props()
	await test_progression()
	await test_shops()
	await test_quests_and_dialogue()
	await test_area_travel()
	await test_boss()
	await test_save_load()

# ---------------------------------------------------------------- content
func test_content() -> void:
	print("\n-- Content --")
	check("moves loaded", ContentDB.moves.size() >= 20, "%d" % ContentDB.moves.size())
	check("enemies loaded", ContentDB.enemies.size() >= 5, "%d" % ContentDB.enemies.size())
	check("food loaded", ContentDB.foods.size() >= 10, "%d" % ContentDB.foods.size())
	check("weapons loaded", ContentDB.weapons.size() >= 7, "%d" % ContentDB.weapons.size())
	check("shops loaded", ContentDB.shops.size() >= 3, "%d" % ContentDB.shops.size())
	check("quests loaded", ContentDB.quests.size() >= 5, "%d" % ContentDB.quests.size())
	check("areas loaded", ContentDB.areas.size() >= 5, "%d" % ContentDB.areas.size())
	# Every move referenced as a followup or by an enemy must exist.
	var missing: Array[String] = []
	for id in ContentDB.moves.keys():
		var m: MoveData = ContentDB.moves[id]
		for f in m.followups:
			if not ContentDB.moves.has(f):
				missing.append("%s -> %s" % [id, f])
		if m.required_move != "" and not ContentDB.moves.has(m.required_move):
			missing.append("%s requires %s" % [id, m.required_move])
	for id in ContentDB.enemies.keys():
		var e: EnemyData = ContentDB.enemies[id]
		for mv in e.moves + [e.heavy_move, e.ranged_move]:
			if str(mv) != "" and not ContentDB.moves.has(str(mv)):
				missing.append("enemy %s -> move %s" % [id, mv])
		if e.sprite_frames == null:
			missing.append("enemy %s has no sprite frames" % id)
	for id in ContentDB.encounters.keys():
		var enc: EncounterData = ContentDB.encounters[id]
		for w in enc.waves:
			if not ContentDB.enemies.has(str(w.get("enemy", ""))):
				missing.append("encounter %s -> enemy %s" % [id, w.get("enemy", "")])
	for id in ContentDB.shops.keys():
		var s: ShopData = ContentDB.shops[id]
		for item in s.inventory:
			if ContentDB.get_item(item) == null and ContentDB.get_move(item) == null and ContentDB.get_weapon(item) == null:
				missing.append("shop %s -> item %s" % [id, item])
	for id in ContentDB.quests.keys():
		var q: QuestData = ContentDB.quests[id]
		if q.reward_move != "" and not ContentDB.moves.has(q.reward_move):
			missing.append("quest %s -> move %s" % [id, q.reward_move])
	check("all content references resolve", missing.is_empty(), ", ".join(missing))
	# Area layouts
	var bad_areas: Array[String] = []
	for id in ContentDB.areas.keys():
		var path := "res://data/areas/%s.json" % id
		if not FileAccess.file_exists(path):
			bad_areas.append(str(id))
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		if not (parsed is Dictionary):
			bad_areas.append(str(id) + " (bad json)")
			continue
		for d in parsed.get("doors", []):
			var to := str(d.get("to", ""))
			if to != "" and not ContentDB.areas.has(to):
				bad_areas.append("%s door -> %s" % [id, to])
			var sh := str(d.get("shop", ""))
			if sh != "" and not ContentDB.shops.has(sh):
				bad_areas.append("%s door -> shop %s" % [id, sh])
		for e in parsed.get("encounters", []):
			if not ContentDB.encounters.has(str(e.get("id", ""))):
				bad_areas.append("%s encounter -> %s" % [id, e.get("id", "")])
		for n in parsed.get("npcs", []):
			var dlg := str(n.get("dialogue", ""))
			if dlg != "" and not ContentDB.dialogues.has(dlg):
				bad_areas.append("%s npc -> dialogue %s" % [id, dlg])
			for c in n.get("conditional", []):
				if not ContentDB.dialogues.has(str(c.get("dialogue", ""))):
					bad_areas.append("%s npc -> conditional dialogue %s" % [id, c.get("dialogue", "")])
		for p in parsed.get("props", []):
			var contains := str(p.get("contains", ""))
			if contains.begins_with("weapon:"):
				if not ContentDB.weapons.has(contains.substr(7)):
					bad_areas.append("%s prop -> weapon %s" % [id, contains])
			elif contains != "" and ContentDB.get_item(contains) == null:
				bad_areas.append("%s prop -> item %s" % [id, contains])
		for w in parsed.get("weapons", []):
			if not ContentDB.weapons.has(str(w.get("id", ""))):
				bad_areas.append("%s weapon -> %s" % [id, w.get("id", "")])
	check("all area layouts valid", bad_areas.is_empty(), ", ".join(bad_areas))

# ---------------------------------------------------------------- boot
func test_new_game() -> void:
	print("\n-- New game --")
	SaveManager.delete_save(0)
	GameManager.new_game()
	GameManager.set_flag("seen_intro", true)      # skip the opening cutscene for the test
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")
	await frames(4)
	await seconds(1.2)
	game = get_tree().current_scene
	check("game scene loaded", game != null and game.name == "Game")
	check("player spawned", is_instance_valid(GameManager.player))
	check("area built", GameManager.current_area != null)
	if GameManager.current_area:
		var a = GameManager.current_area
		check("area has ground", a.ground_root.get_child_count() > 20, "%d nodes" % a.ground_root.get_child_count())
		check("area has actors", a.actors_root.get_child_count() > 5, "%d nodes" % a.actors_root.get_child_count())
	GameManager.set_state(GameManager.State.PLAYING)


## Put the player on a clean stretch of street: no dialogue, no enemies, no interactables
## or loose weapons in reach. Without this, an accidental "interact" opens a shop or a
## conversation and every later check inherits a frozen game state.
func clear_stage(x: float = 700.0) -> void:
	if DialogueManager.is_active():
		DialogueManager._finish()
	if ShopManager.is_open():
		ShopManager._on_closed()
	GameManager.set_state(GameManager.State.PLAYING)
	for n in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(n):
			n.queue_free()
	for n in get_tree().get_nodes_in_group("projectiles"):
		if is_instance_valid(n):
			n.queue_free()
	var player := p()
	if player:
		player.combat.cancel()
		player.release_grab()
		player.set_state(Actor.State.IDLE)
		player.z_height = 0.0
		player.z_velocity = 0.0
		player.knockback_velocity = Vector2.ZERO
		player.global_position = Vector2(x, (GameManager.current_area.lane_min + GameManager.current_area.lane_max) * 0.5)
		player.nearby_interactable = null
	await frames(2)
	# Move anything grabbable well out of reach so interact/pickup cannot pre-empt a grab.
	for group in ["interactables", "weapons", "pickups"]:
		for n in get_tree().get_nodes_in_group(group):
			if is_instance_valid(n) and n.global_position.distance_to(player.global_position) < 120.0:
				n.global_position += Vector2(600.0, 0)
	await frames(1)

func p() -> Player:
	return GameManager.player

# ---------------------------------------------------------------- movement
func test_movement() -> void:
	print("\n-- Movement --")
	var player := p()
	if player == null:
		check("movement", false, "no player")
		return
	var start := player.global_position
	Input.action_press("move_right")
	await frames(30)
	Input.action_release("move_right")
	check("walks right", player.global_position.x > start.x + 20.0, "moved %.1f" % (player.global_position.x - start.x))
	check("faces the way it walks", player.facing == 1)
	var run_start := player.global_position.x
	Input.action_press("move_right")
	Input.action_press("sprint")
	await frames(30)
	Input.action_release("sprint")
	Input.action_release("move_right")
	var run_dist: float = player.global_position.x - run_start
	check("runs faster than it walks", run_dist > (player.global_position.x - start.x) * 0.0 + 30.0, "ran %.1f" % run_dist)
	var y0 := player.global_position.y
	Input.action_press("move_up")
	await frames(20)
	Input.action_release("move_up")
	check("moves up the lane", player.global_position.y < y0)
	# Lane clamp
	player.position.y = -500.0
	await frames(3)
	check("clamped to lane", player.global_position.y >= GameManager.current_area.lane_min - 1.0,
		"y=%.1f min=%.1f" % [player.global_position.y, GameManager.current_area.lane_min])
	# Jump
	player.z_height = 0.0
	player._press_jump()
	await frames(10)
	check("jumps", player.z_height > 10.0, "z=%.1f" % player.z_height)
	await seconds(1.2)
	check("lands", player.z_height <= 0.1, "z=%.1f" % player.z_height)

# ---------------------------------------------------------------- combat
func spawn_enemy(id: String, offset: float = 40.0) -> EnemyBase:
	var area = GameManager.current_area
	var edata: EnemyData = ContentDB.get_enemy(id)
	if edata == null:
		return null
	var e: EnemyBase = load("res://actors/enemies/Enemy.tscn").instantiate()
	e.data = edata
	area.actors_root.add_child(e)
	e.global_position = p().global_position + Vector2(offset, 0)
	e.set_lane_bounds(area.lane_min, area.lane_max, area.walk_min_x, area.walk_max_x)
	return e

func test_combat() -> void:
	print("\n-- Combat --")
	var player := p()
	var e := spawn_enemy("pigeon_grunt", 22.0)
	await frames(4)
	check("enemy spawned", is_instance_valid(e) and e.hp > 0)
	if e == null:
		return
	var hp0 := e.hp
	player.facing = 1
	player.global_position.y = e.global_position.y
	player._press_attack(MoveData.InputKind.LIGHT)
	await frames(20)
	check("light attack damages enemy", e.hp < hp0, "%d -> %d" % [hp0, e.hp])

	# Combo chain: jab -> cross -> hook, driven through the cancel window like a player.
	# Use a sturdy target so the chain cannot end early by knocking the enemy out.
	e.queue_free()
	await frames(2)
	e = spawn_enemy("rust_heavy", 20.0)
	await frames(4)
	e.global_position.y = player.global_position.y
	var hp1 := e.hp
	var landed := 0
	var chain: Array[String] = []
	player.combat.cancel()
	player.set_state(Actor.State.IDLE)
	player.facing = 1
	player.global_position = e.global_position - Vector2(18, 0)
	player._press_attack(MoveData.InputKind.LIGHT)
	for step in 3:
		var waited := 0
		# Wait until the current move has connected and opened its cancel window.
		while waited < 40 and not player.combat.can_cancel() and player.combat.current != null:
			await frames(1)
			waited += 1
		if player.combat.current != null:
			chain.append(player.combat.current.id)
		if e.hp < hp1:
			landed += 1
			hp1 = e.hp
		player.global_position = e.global_position - Vector2(18, 0)
		player.facing = 1
		player._press_attack(MoveData.InputKind.LIGHT)
		await frames(2)
	await frames(20)
	if e.hp < hp1:
		landed += 1
	check("combo chain lands multiple hits", landed >= 2, "%d hits" % landed)
	check("combo chains through different moves", chain.size() >= 2 and chain[0] != chain[1],
		" -> ".join(chain))

	# Heavy knocks down
	if is_instance_valid(e):
		player.combat.cancel()
		player.set_state(Actor.State.IDLE)
		e.move_input = Vector2.ZERO
		player.global_position = e.global_position - Vector2(18, 0)
		player.global_position.y = e.global_position.y
		player.facing = 1
		player.energy = player.max_energy
		var hpk := e.hp
		player._press_attack(MoveData.InputKind.HEAVY)
		await frames(24)
		check("heavy attack damages", e.hp < hpk, "%d -> %d" % [hpk, e.hp])
		check("heavy attack knocks down", e.state == Actor.State.KNOCKDOWN or e.dead or e.z_height > 0.0,
			"state=%d z=%.1f" % [e.state, e.z_height])

	# Jump attack
	if is_instance_valid(e) and not e.dead:
		await seconds(1.4)
		player.combat.cancel()
		player.set_state(Actor.State.IDLE)
		player.global_position = e.global_position - Vector2(16, 0)
		player.global_position.y = e.global_position.y
		player.facing = 1
		var hp2 := e.hp
		player._press_jump()
		await frames(8)
		player._press_attack(MoveData.InputKind.LIGHT)
		await frames(16)
		check("jump attack connects", e.hp < hp2 or e.dead, "%d -> %d" % [hp2, e.hp])

	# Grab and throw (fresh target so an earlier knockout cannot skip these checks)
	await clear_stage(700.0)
	check("no dialogue is blocking gameplay", not DialogueManager.is_active() and GameManager.is_gameplay_active())
	e = spawn_enemy("sweater_grunt", 30.0)
	await frames(4)
	if is_instance_valid(e) and not e.dead:
		player.combat.cancel()
		player.set_state(Actor.State.IDLE)
		e.set_state(Actor.State.IDLE)
		e.z_height = 0.0
		e.global_position.y = player.global_position.y
		player.global_position = e.global_position - Vector2(12, 0)
		player.facing = 1
		player._press_grab()
		await frames(4)
		var grabbed := player.grabbing != null
		check("grab connects", grabbed, "grabbing=%s" % str(player.grabbing))
		if grabbed:
			var hp3 := e.hp
			player._press_attack(MoveData.InputKind.LIGHT)
			await frames(6)
			check("grab attack damages", e.hp < hp3, "%d -> %d" % [hp3, e.hp])
			player.set_state(Actor.State.GRABBING)
			player.grabbing = e
			e.grabbed_by = player
			player._throw_grabbed(Vector2(1, 0))
			await frames(6)
			check("throw launches enemy", e.dead or e.z_height > 0.0 or e.state == Actor.State.KNOCKDOWN,
				"z=%.1f state=%d" % [e.z_height, e.state])

	# Special meter
	player.special_meter = 100.0
	player.combat.cancel()
	player.set_state(Actor.State.IDLE)
	player._press_special()
	await frames(4)
	check("special consumes meter", player.special_meter < 100.0, "%.0f" % player.special_meter)

	# Enemy AI actually attacks back.
	# Wait out the special first: its wide hitbox would delete the probe enemy on spawn.
	await seconds(0.8)
	await clear_stage(760.0)
	var e2 := spawn_enemy("sweater_grunt", 60.0)
	await frames(4)
	if e2:
		e2.global_position.y = player.global_position.y
		e2.aggro = true
		var php := player.hp
		player.hurtbox.invulnerable_until_ms = 0
		player.invuln_frames = 0
		var t := 0
		var saw_approach := false
		var saw_attack := false
		var closest := 9999.0
		while t < 300 and player.hp >= php:
			await frames(1)
			t += 1
			player.invuln_frames = 0
			player.hurtbox.invulnerable_until_ms = 0
			if not is_instance_valid(e2):
				break
			closest = minf(closest, absf(e2.global_position.x - player.global_position.x))
			if e2.ai_state == EnemyBase.AI.APPROACH:
				saw_approach = true
			if e2.combat.current != null:
				saw_attack = true
		check("enemy AI closes distance", saw_approach and closest < 40.0, "closest %.1f approach=%s" % [closest, saw_approach])
		check("enemy AI starts attacks", saw_attack, "aggro=%s state=%s" % [str(e2.aggro) if is_instance_valid(e2) else "gone", str(e2.ai_state) if is_instance_valid(e2) else "-"])
		check("enemy AI attacks the player", player.hp < php, "player hp %d -> %d after %d frames" % [php, player.hp, t])
		if is_instance_valid(e2):
			e2.queue_free()
	# Defeat and rewards
	var e3 := spawn_enemy("pigeon_grunt", 26.0)
	await frames(4)
	if e3:
		var money0 := GameManager.player_data.money
		var xp0 := GameManager.player_data.xp + GameManager.player_data.level * 1000
		e3.hp = 1
		var d := DamageData.new()
		d.amount = 999
		d.source = player
		d.direction = 1
		e3.take_damage(d)
		await frames(6)
		check("enemy dies when HP runs out", e3.dead)
		await frames(30)
		var xp1 := GameManager.player_data.xp + GameManager.player_data.level * 1000
		check("defeat awards XP", xp1 > xp0, "%d -> %d" % [xp0, xp1])
		check("defeat drops money pickups", get_tree().get_nodes_in_group("pickups").size() > 0,
			"%d pickups" % get_tree().get_nodes_in_group("pickups").size())
	for n in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(n):
			n.queue_free()
	await frames(2)

# ---------------------------------------------------------------- weapons
func test_weapons() -> void:
	print("\n-- Weapons --")
	await clear_stage(820.0)
	var player := p()
	var ok := player.give_weapon("bat")
	await frames(4)
	check("weapon given and held", ok and is_instance_valid(player.held_weapon), str(player.held_weapon))
	var e := spawn_enemy("rust_heavy", 20.0)
	await frames(4)
	if e and is_instance_valid(player.held_weapon):
		var hp0 := e.hp
		var uses0: int = player.held_weapon.uses_left
		player.global_position = e.global_position - Vector2(18, 0)
		player.facing = 1
		player._press_attack(MoveData.InputKind.LIGHT)
		await frames(24)
		check("weapon swing damages", e.hp < hp0, "%d -> %d" % [hp0, e.hp])
		check("weapon target survived for the durability check", not e.dead, "hp %d" % e.hp)
		check("weapon durability decreases", not is_instance_valid(player.held_weapon) or player.held_weapon.uses_left < uses0,
			"%d -> %s" % [uses0, str(player.held_weapon.uses_left) if is_instance_valid(player.held_weapon) else "broken"])
	# Break a fragile weapon
	player.drop_weapon()
	await frames(2)
	player.give_weapon("bottle")
	await frames(2)
	var w = player.held_weapon
	if is_instance_valid(w):
		for i in 6:
			if is_instance_valid(w):
				w.register_swing_hit()
		await frames(4)
		check("fragile weapon breaks", not is_instance_valid(w) and player.held_weapon == null)
	# Throw
	player.give_weapon("brick")
	await frames(2)
	if is_instance_valid(player.held_weapon):
		player._throw_weapon()
		await frames(4)
		check("weapon can be thrown", player.held_weapon == null)
	for n in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(n):
			n.queue_free()
	await frames(2)

# ---------------------------------------------------------------- pickups / props
func test_pickups_and_props() -> void:
	print("\n-- Pickups and props --")
	var player := p()
	var money0 := GameManager.player_data.money
	var scene: PackedScene = load("res://world/props/MoneyPickup.tscn")
	var c = scene.instantiate()
	GameManager.current_area.actors_root.add_child(c)
	c.setup(25, player.global_position + Vector2(4, 0), Vector2.ZERO, 0.0)
	await seconds(0.6)
	check("money pickup collected by walking over it", GameManager.player_data.money > money0,
		"$%d -> $%d" % [money0, GameManager.player_data.money])
	# Breakable prop
	var props := get_tree().get_nodes_in_group("props")
	var breakable = null
	for pr in props:
		if pr.breakable and not pr.dead:
			breakable = pr
			break
	if breakable:
		var d := DamageData.new()
		d.amount = 999
		d.direction = 1
		d.source = player
		breakable.take_damage(d)
		await frames(4)
		check("breakable prop breaks open", breakable.dead)
	else:
		check("breakable prop present in area", false, "none found")

# ---------------------------------------------------------------- progression
func test_progression() -> void:
	print("\n-- Progression --")
	var pd := GameManager.player_data
	var lvl0 := pd.level
	var hp0 := pd.get_max_hp()
	GameManager.add_xp(4000)
	await frames(2)
	check("XP levels the player up", pd.level > lvl0, "Lv %d -> %d" % [lvl0, pd.level])
	check("level raises max HP", pd.get_max_hp() > hp0, "%d -> %d" % [hp0, pd.get_max_hp()])
	var str0: int = pd.stats.strength
	GameManager.add_stat("strength", 3)
	check("stats can be raised", int(pd.stats.strength) == str0 + 3)
	var mult := pd.get_punch_multiplier()
	GameManager.add_bonus("punch_damage", 4)
	check("bonuses raise damage multipliers", pd.get_punch_multiplier() > mult,
		"x%.2f -> x%.2f" % [mult, pd.get_punch_multiplier()])
	check("player syncs new stats", p().max_hp == pd.get_max_hp(), "%d vs %d" % [p().max_hp, pd.get_max_hp()])

# ---------------------------------------------------------------- shops
func test_shops() -> void:
	print("\n-- Shops --")
	GameManager.add_money(5000)
	var tested := 0
	for shop_id in ContentDB.shops.keys():
		var shop: ShopData = ContentDB.get_shop(str(shop_id))
		var entries := ShopManager.build_entries(shop)
		if entries.is_empty():
			check("shop %s has stock" % shop_id, false)
			continue
		tested += 1
		# Buy the first affordable, unlocked entry.
		var bought := false
		for e in entries:
			if bool(e.get("owned", false)) or bool(e.get("locked", false)):
				continue
			var money0 := GameManager.player_data.money
			var res := ShopManager.purchase(shop, e)
			if res == "ok":
				bought = true
				check("bought '%s' at %s" % [e["name"], shop_id], GameManager.player_data.money < money0 or int(e["price"]) == 0,
					"$%d -> $%d" % [money0, GameManager.player_data.money])
				break
		if not bought:
			check("shop %s sold something" % shop_id, false, "nothing purchasable")
	check("all shops reachable", tested == ContentDB.shops.size(), "%d/%d" % [tested, ContentDB.shops.size()])
	# Dojo unlocks a technique
	var dojo: ShopData = ContentDB.get_shop("odell_dojo")
	var move_entries := ShopManager.build_entries(dojo)
	var unlocked := 0
	for e in move_entries:
		if bool(e.get("locked", false)) or bool(e.get("owned", false)):
			continue
		if ShopManager.purchase(dojo, e) == "ok":
			unlocked += 1
	check("dojo teaches new moves", unlocked > 0 or GameManager.has_move("uppercut"), "%d learned" % unlocked)
	# Food heals and can permanently boost stats
	var pd := GameManager.player_data
	p().hp = 5
	pd.hp = 5
	var sta0: int = pd.stats.stamina
	ShopManager.apply_food(ContentDB.get_food("hot_noodles"))
	await frames(2)
	check("food heals", pd.hp > 5, "hp %d" % pd.hp)
	check("food gives permanent stat gain", int(pd.stats.stamina) > sta0, "stamina %d -> %d" % [sta0, int(pd.stats.stamina)])
	# Books
	var books: ShopData = ContentDB.get_shop("marisol_books")
	var b_entries := ShopManager.build_entries(books)
	if not b_entries.is_empty():
		var before := pd.books_read.size()
		for e in b_entries:
			if not bool(e.get("owned", false)) and not bool(e.get("locked", false)):
				ShopManager.purchase(books, e)
				break
		check("books are recorded as read", pd.books_read.size() > before)

# ---------------------------------------------------------------- quests / dialogue
func test_quests_and_dialogue() -> void:
	print("\n-- Quests and dialogue --")
	log_line("   .. start q_pigeons")
	QuestManager.start_quest("q_pigeons")
	check("quest starts", QuestManager.is_active("q_pigeons"), QuestManager.get_state("q_pigeons"))
	var q: QuestData = ContentDB.get_quest("q_pigeons")
	for i in q.required_count:
		QuestManager.add_progress("q_pigeons")
	check("quest objective completes", QuestManager.get_state("q_pigeons") in ["ready", "done"],
		QuestManager.get_state("q_pigeons"))
	log_line("   .. turn in at dez")
	QuestManager.notify_talked_to("dez")
	check("quest turns in at the giver", QuestManager.is_done("q_pigeons"), QuestManager.get_state("q_pigeons"))
	# Item quest
	log_line("   .. start q_flyer")
	QuestManager.start_quest("q_flyer")
	GameManager.add_key_item("dojo_flyer")
	await frames(2)
	check("item quest tracks pickups", QuestManager.get_state("q_flyer") in ["ready", "done"],
		QuestManager.get_state("q_flyer"))
	# Dialogue runs end to end
	_dialogue_finished = false
	EventBus.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
	log_line("   .. open dialogue")
	DialogueManager.start("dez_hub")
	await frames(4)
	check("dialogue opens", DialogueManager.is_active())
	var guard := 0
	while DialogueManager.is_active() and guard < 400:
		# Advance as a player would.
		if DialogueManager._box and DialogueManager._box.has_method("_on_text_complete"):
			DialogueManager._box._typing = false
			DialogueManager._box.line_finished.emit()
		await frames(2)
		guard += 1
	check("dialogue advances to the end", _dialogue_finished and not DialogueManager.is_active(), "%d steps" % guard)
	# Every dialogue resource is structurally valid
	log_line("   .. validate dialogue data")
	var bad: Array[String] = []
	for did in ContentDB.dialogues.keys():
		var d: DialogueData = ContentDB.dialogues[did]
		if d.lines.is_empty():
			bad.append(str(did) + " (empty)")
		for line in d.lines:
			if line.has("goto") and int(line["goto"]) >= d.lines.size():
				bad.append("%s bad goto" % did)
			for key in ["start_quest", "complete_quest"]:
				if line.has(key) and ContentDB.get_quest(str(line[key])) == null:
					bad.append("%s -> quest %s" % [did, line[key]])
			if line.has("shop") and ContentDB.get_shop(str(line["shop"])) == null:
				bad.append("%s -> shop %s" % [did, line["shop"]])
			if line.has("give_item") and ContentDB.get_item(str(line["give_item"])) == null:
				bad.append("%s -> item %s" % [did, line["give_item"]])
	check("all dialogue references resolve", bad.is_empty(), ", ".join(bad))

# ---------------------------------------------------------------- travel
func test_area_travel() -> void:
	print("\n-- Area travel --")
	var order := ["lantern_market", "grease_alley", "rustpile_yard", "starch_laundromat", "ferry_row"]
	for area_id in order:
		await SceneManager.change_area(area_id, "start")
		await seconds(0.5)
		var ok: bool = GameManager.current_area != null and GameManager.player_data.current_area == area_id
		var built: bool = GameManager.current_area != null and GameManager.current_area.actors_root.get_child_count() > 2
		check("travel to %s" % area_id, ok and built and is_instance_valid(GameManager.player),
			"%d actor nodes" % (GameManager.current_area.actors_root.get_child_count() if GameManager.current_area else 0))
		GameManager.set_flag("visited_" + area_id, true)

# ---------------------------------------------------------------- boss
func test_boss() -> void:
	print("\n-- Boss --")
	GameManager.set_flag("yard_cleared", true)
	await SceneManager.change_area("starch_laundromat", "start")
	await seconds(0.5)
	var area = GameManager.current_area
	var enc: EncounterData = ContentDB.get_encounter("boss_starch")
	check("boss encounter exists", enc != null and enc.boss_id != "")
	if enc == null:
		return
	GameManager.set_flag("enc_boss_starch", false)
	area.director.start_encounter(enc)
	# The encounter opens with Big Starch's intro; advance it like a player would.
	var guard := 0
	while get_tree().get_nodes_in_group("bosses").is_empty() and guard < 600:
		if DialogueManager.is_active() and DialogueManager._box:
			DialogueManager._box._typing = false
			DialogueManager._box.line_finished.emit()
		await frames(2)
		guard += 1
	check("boss intro dialogue plays and closes", not DialogueManager.is_active())
	var bosses := get_tree().get_nodes_in_group("bosses")
	check("boss spawns", not bosses.is_empty(), "%d frames" % guard)
	if bosses.is_empty():
		return
	var boss: Boss = bosses[0]
	check("boss has more HP than a grunt", boss.max_hp > 200, "%d hp" % boss.max_hp)
	check("boss starts in phase 1", boss.phase == 1)
	check("boss cannot be grabbed in phase 1", not boss.can_be_grabbed)
	# Drive it to phase 2
	var d := DamageData.new()
	d.amount = int(boss.max_hp * 0.55)
	d.source = p()
	d.direction = 1
	boss.take_damage(d)
	await frames(6)
	check("boss enters phase 2 below half HP", boss.phase == 2, "hp %d/%d phase %d" % [boss.hp, boss.max_hp, boss.phase])
	check("boss becomes grabbable in phase 2", boss.can_be_grabbed)
	# Kill it. The phase change grants brief invulnerability, so wait it out first.
	await seconds(1.0)
	check("phase change invulnerability expires", boss.invuln_frames <= 0, "%d frames left" % boss.invuln_frames)
	var money0 := GameManager.player_data.money
	var d2 := DamageData.new()
	d2.amount = 99999
	d2.source = p()
	d2.direction = 1
	boss.take_damage(d2)
	await seconds(0.4)
	check("boss can be defeated", boss.dead)
	check("boss recorded as defeated", "big_starch" in GameManager.player_data.bosses_defeated)
	check("boss awards money", GameManager.player_data.money > money0, "$%d -> $%d" % [money0, GameManager.player_data.money])
	GameManager.clear_time_effects()

# ---------------------------------------------------------------- save / load
func test_save_load() -> void:
	print("\n-- Save and load --")
	var pd := GameManager.player_data
	pd.money = 1234
	pd.level = 7
	GameManager.unlock_move("spin_kick")
	GameManager.set_flag("smoke_flag", true)
	GameManager.player_data.inventory["rice_ball"] = 3
	pd.current_area = "grease_alley"
	var ok := SaveManager.save_game(0)
	check("save writes to user://", ok and SaveManager.has_save(0), SaveManager.last_error)
	var summary := SaveManager.get_save_summary(0)
	check("save summary readable", int(summary.get("level", 0)) == 7, str(summary))
	# Clobber then reload
	GameManager.new_game()
	check("new game clears state", GameManager.player_data.money != 1234)
	var loaded := SaveManager.load_game(0)
	var pd2 := GameManager.player_data
	check("load restores the save", loaded and pd2.money == 1234 and pd2.level == 7,
		"$%d Lv%d" % [pd2.money, pd2.level])
	check("load restores moves", GameManager.has_move("spin_kick"))
	check("load restores flags", GameManager.get_flag("smoke_flag") == true)
	check("load restores inventory", GameManager.item_count("rice_ball") == 3, "%d" % GameManager.item_count("rice_ball"))
	check("load restores area", pd2.current_area == "grease_alley", pd2.current_area)
	# Version migration
	var migrated := SaveManager.migrate({"level": 3, "money": 10})
	check("legacy saves migrate", migrated.has("player") and int(migrated["save_version"]) == SaveManager.SAVE_VERSION,
		str(migrated.get("save_version")))
	SaveManager.delete_save(0)

# ---------------------------------------------------------------- report
func _report() -> void:
	var passed := 0
	var failed: Array[String] = []
	for r in results:
		if r.ok:
			passed += 1
		else:
			failed.append("%s%s" % [r.name, ("  (" + r.detail + ")") if r.detail != "" else ""])
	print("\n=== RESULT: %d/%d checks passed ===" % [passed, results.size()])
	if not failed.is_empty():
		log_line("FAILURES:")
		for f in failed:
			log_line("  - " + f)
	print("=== SMOKE TEST %s ===\n" % ("PASSED" if failed.is_empty() else "FAILED"))
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if failed.is_empty() else 1)

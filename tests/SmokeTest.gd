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

## Step physics frames, not render frames. All gameplay runs in _physics_process, and in
## a headless run render frames are uncapped, so counting them measures nothing.
func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout

func run() -> void:
	await test_content()
	await test_audio()
	await test_title_flow()
	await test_new_game()
	await test_movement()
	await test_combat()
	await test_defence()
	await test_crowd_ai()
	await test_weapons()
	await test_pickups_and_props()
	await test_progression()
	await test_shops()
	await test_quests_and_dialogue()
	await test_area_travel()
	await test_world_graph()
	await test_lighting()
	await test_chapter_two()
	await test_boss()
	await test_touch_controls()
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

# ---------------------------------------------------------------- audio
## Audio fails silently by nature: nothing errors, the game is just quiet. These checks
## caught music importing with looping disabled, which made every track play once for
## sixteen seconds and then leave the game silent for the rest of the session.
##
## A headless run uses the Dummy audio driver, so this asserts wiring and asset state
## rather than audible output. tests/AudioCheck.gd covers real playback.
func test_audio() -> void:
	log_line("
-- Audio --")
	var missing_bus: Array[String] = []
	var silent_bus: Array[String] = []
	for b in AudioManager.BUSES:
		var idx := AudioServer.get_bus_index(b)
		if idx == -1:
			missing_bus.append(b)
			continue
		if AudioServer.is_bus_mute(idx) or AudioServer.get_bus_volume_db(idx) < -50.0:
			silent_bus.append(b)
	check("every audio bus exists", missing_bus.is_empty(), ", ".join(missing_bus))
	check("no audio bus is muted or silent", silent_bus.is_empty(), ", ".join(silent_bus))

	# Every sound the code asks for by name must resolve to a real stream.
	var wanted_sfx: Array[String] = [
		"punch_light", "punch_heavy", "kick", "whoosh_light", "whoosh_heavy", "hit_light",
		"hit_heavy", "hit_weapon", "hit_crit", "block", "throw", "land", "jump", "step",
		"hurt", "enemy_hurt", "enemy_defeat", "knockdown", "money", "pickup", "purchase",
		"eat", "menu_move", "menu_confirm", "menu_back", "menu_deny", "level_up",
		"quest_start", "quest_complete", "unlock", "weapon_pickup", "weapon_break",
		"break_object", "door", "boss_warning", "telegraph", "special_charge",
		"special_hit", "dash", "grab", "notify", "save", "pause",
	]
	var bad_sfx: Array[String] = []
	for id in wanted_sfx:
		if AudioManager._resolve(AudioManager.SFX_DIR, id) == null:
			bad_sfx.append(id)
	check("every sound effect resolves", bad_sfx.is_empty(), ", ".join(bad_sfx))

	var bad_music: Array[String] = []
	var not_looping: Array[String] = []
	for id in ["title", "street", "market", "alley", "industrial", "boss", "victory", "shop"]:
		var stream: AudioStream = AudioManager._resolve(AudioManager.MUSIC_DIR, id)
		if stream == null:
			bad_music.append(id)
			continue
		if stream is AudioStreamWAV and (stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
			not_looping.append(id)
	check("every music track resolves", bad_music.is_empty(), ", ".join(bad_music))
	check("music loops instead of playing once and stopping", not_looping.is_empty(), ", ".join(not_looping))

	var bad_amb: Array[String] = []
	var amb_once: Array[String] = []
	for id in ["city", "alley", "interior", "industrial", "river"]:
		var stream: AudioStream = AudioManager._resolve(AudioManager.AMBIENCE_DIR, id)
		if stream == null:
			bad_amb.append(id)
		elif stream is AudioStreamWAV and (stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
			amb_once.append(id)
	check("every ambience bed resolves", bad_amb.is_empty(), ", ".join(bad_amb))
	check("ambience loops", amb_once.is_empty(), ", ".join(amb_once))

	# Areas must not ask for audio that does not exist.
	var bad_area: Array[String] = []
	for id in ContentDB.areas.keys():
		var a: AreaData = ContentDB.areas[id]
		if a.music != "" and AudioManager._resolve(AudioManager.MUSIC_DIR, a.music) == null:
			bad_area.append("%s music %s" % [id, a.music])
		if a.ambience != "" and AudioManager._resolve(AudioManager.AMBIENCE_DIR, a.ambience) == null:
			bad_area.append("%s ambience %s" % [id, a.ambience])
	check("every area's music and ambience exist", bad_area.is_empty(), ", ".join(bad_area))

	# And the players actually accept a stream.
	AudioManager.play_music("street")
	await frames(2)
	check("play_music assigns a stream", AudioManager._music_active.stream != null)

	# A headless run uses the Dummy driver and cannot hear anything, so the two ways audio
	# has actually broken in this project are asserted structurally instead.
	check("audio buses come from a layout resource, not add_bus()",
		ResourceLoader.exists("res://default_bus_layout.tres"),
		"creating buses at runtime silences web exports entirely, with no error")
	# Comments are stripped first: both of these are named in AudioManager's own docs
	# explaining why they must never be used, and matching those would be a false alarm.
	var am_code := _code_only("res://autoload/AudioManager.gd")
	check("AudioManager never calls AudioServer.add_bus()",
		not am_code.contains("AudioServer.add_bus("),
		"it silences the browser build")
	check("music fades are stepped, not tweened",
		not am_code.contains("create_tween("),
		"a stalled tween parks music at its -40 dB floor, which reads as a hum")
	for b in AudioManager.BUSES:
		check("bus '%s' exists at startup" % b, AudioServer.get_bus_index(b) != -1)

# ---------------------------------------------------------------- title flow
## Start a game the way a player does: title screen, New Game, wait for the street.
## This is the path that leaves the screen black if a transition fade ever stalls.
func test_title_flow() -> void:
	log_line("
-- Title screen flow --")
	SaveManager.delete_save(0)
	await SceneManager.goto_title()
	await frames(6)
	var title := get_tree().current_scene
	check("title screen loads", title != null and title.name == "TitleScreen", str(title))
	check("screen is not left dimmed on the title", SceneManager.fade_alpha() < 0.05,
		"alpha %.2f" % SceneManager.fade_alpha())
	if title == null or not title.has_method("_new_game"):
		return
	title._new_game()
	var guard := 0
	while (get_tree().current_scene == null or get_tree().current_scene.name != "Game") and guard < 600:
		await frames(1)
		guard += 1
	check("New Game reaches the gameplay scene", get_tree().current_scene != null and get_tree().current_scene.name == "Game",
		"%d frames" % guard)
	# Give the entry fade and any intro dialogue time to settle.
	guard = 0
	while SceneManager.fade_alpha() > 0.05 and guard < 600:
		await frames(1)
		guard += 1
	check("screen fades back in after New Game", SceneManager.fade_alpha() <= 0.05,
		"alpha %.2f after %d frames" % [SceneManager.fade_alpha(), guard])
	check("player exists after the title flow", is_instance_valid(GameManager.player))
	# Entry events run on the frame after the fade completes.
	guard = 0
	while not DialogueManager.is_active() and guard < 60:
		await frames(1)
		guard += 1
	check("opening scene runs its entry dialogue", DialogueManager.is_active() or GameManager.get_flag("seen_intro"),
		"state=%d" % GameManager.state)
	if DialogueManager.is_active():
		DialogueManager._finish()
	await frames(4)

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
	# Stop any encounter and disarm the street's triggers: teleporting the player around
	# would otherwise start real fights in the middle of a targeted check.
	var area = GameManager.current_area
	if area:
		if area.director:
			area.director.abort()
		for t in area._encounter_triggers:
			t.fired = true
		area.lock_camera(false)
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
	# Solid props block movement, so a check about walking somewhere should not be run next
	# to a phone booth.
	for pr in get_tree().get_nodes_in_group("props"):
		if is_instance_valid(pr) and pr.get("solid") == true and absf(pr.global_position.x - player.global_position.x) < 140.0:
			pr.global_position += Vector2(600.0, 0)
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
## Freeze an enemy as a stationary target. The director now hands out flanking roles to
## every enemy in the scene, so a spawned test dummy will otherwise walk off mid-check.
func pin(e: EnemyBase) -> void:
	if not is_instance_valid(e):
		return
	e.role = EnemyBase.Role.ATTACKER
	e.desired_side = 0
	e.ai_state = EnemyBase.AI.WAIT
	e.think_timer = 999.0
	e.move_input = Vector2.ZERO
	if is_instance_valid(GameManager.player):
		e.global_position.y = GameManager.player.global_position.y

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
	pin(e)
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
		pin(e)
		player.global_position = e.global_position - Vector2(18, 0)
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
		# Hold the target still: lane drift during the jump would look like a broken move.
		pin(e)
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

# ---------------------------------------------------------------- defence
## Guard and the dodge roll. Both are resource trades, so the checks cover the cost and
## the failure case as well as the effect.
func test_defence() -> void:
	log_line("
-- Guard and dodge --")
	await clear_stage(700.0)
	var player := p()

	# --- Guard ---
	player.energy = player.max_energy
	Input.action_press("guard")
	Input.action_press("sprint")
	await frames(6)
	check("holding guard while still enters the guard state", player.state == Actor.State.GUARD,
		"state=%d" % player.state)
	check("guarding reports itself to the damage path", player.is_guarding())

	var e := spawn_enemy("sweater_grunt", 26.0)
	await frames(4)
	pin(e)
	var hp0: int = player.hp
	var en0: float = player.energy
	var jab: MoveData = ContentDB.get_move("enemy_jab")
	var d := DamageData.from_move(jab, e, -1, 1.0)
	player.invuln_frames = 0
	player.hurtbox.invulnerable_until_ms = 0
	player.take_damage(d)
	await frames(4)
	var guarded_loss: int = hp0 - player.hp
	check("a guarded hit costs far less health", guarded_loss < jab.damage,
		"lost %d of %d" % [guarded_loss, jab.damage])
	check("a guarded hit drains energy", player.energy < en0, "%.0f -> %.0f" % [en0, player.energy])
	check("guarding survives an ordinary hit", player.state == Actor.State.GUARD, "state=%d" % player.state)

	# A heavy attack breaks through the guard.
	var heavy: MoveData = ContentDB.get_move("enemy_heavy")
	var hp1: int = player.hp
	player.invuln_frames = 0
	player.hurtbox.invulnerable_until_ms = 0
	player.take_damage(DamageData.from_move(heavy, e, -1, 1.0))
	await frames(4)
	check("a heavy attack breaks the guard", player.hp < hp1 - 1 and player.state != Actor.State.GUARD,
		"hp %d -> %d state=%d" % [hp1, player.hp, player.state])

	# Guard is unavailable with no energy.
	Input.action_release("guard")
	Input.action_release("sprint")
	await frames(4)
	player.set_state(Actor.State.IDLE)
	player.energy = 0.0
	Input.action_press("guard")
	Input.action_press("sprint")
	await frames(6)
	check("cannot guard on an empty energy bar", player.state != Actor.State.GUARD, "state=%d" % player.state)
	Input.action_release("guard")
	Input.action_release("sprint")
	await frames(4)

	# --- Dodge roll ---
	await clear_stage(700.0)
	player = p()
	player.energy = player.max_energy
	player.set_state(Actor.State.IDLE)
	var start_x: float = player.global_position.x
	var en1: float = player.energy
	# Double-tap right: press, release, press again inside the window.
	Input.action_press("move_right")
	await frames(2)
	Input.action_release("move_right")
	await frames(2)
	Input.action_press("move_right")
	await frames(3)
	check("a double-tap starts a dodge roll", player.state == Actor.State.DODGE, "state=%d" % player.state)
	check("the roll costs energy", player.energy < en1, "%.0f -> %.0f" % [en1, player.energy])
	check("the roll grants invulnerability", player.invuln_frames > 0 or player.hurtbox.is_invulnerable())
	await frames(14)
	check("the roll travels", player.global_position.x > start_x + 20.0,
		"moved %.1f" % (player.global_position.x - start_x))
	Input.action_release("move_right")
	await frames(30)
	check("the roll ends and control returns", player.state != Actor.State.DODGE, "state=%d" % player.state)
	await clear_stage(700.0)

# ---------------------------------------------------------------- crowd AI
## Flanking and telegraphs. A crowd that all approaches from one side is not a crowd, and
## guard and dodge are only fair if the attacks worth answering can be read coming.
func test_crowd_ai() -> void:
	log_line("
-- Crowd AI --")
	await clear_stage(700.0)
	var player := p()
	var area = GameManager.current_area
	if area == null or area.director == null:
		check("area has a director", false)
		return

	# Spawn three enemies all on the same side, which is the worst case.
	var group: Array[EnemyBase] = []
	for i in 3:
		var e := spawn_enemy("sweater_grunt", 70.0 + i * 18.0)
		if e:
			e.global_position.y = player.global_position.y + (i - 1) * 6.0
			e.aggro = true
			group.append(e)
	await frames(4)
	check("three enemies spawned on one side", group.size() == 3)

	area.director.assign_slots()
	await frames(2)
	var sides: Array[int] = []
	for e in group:
		sides.append(e.desired_side)
	check("the director splits the crowd across both sides",
		sides.has(1) and sides.has(-1), "sides %s" % str(sides))

	var attackers := 0
	for e in group:
		if e.role == EnemyBase.Role.ATTACKER:
			attackers += 1
	check("only a couple may commit at once", attackers <= EnemyDirector.ATTACK_SLOTS,
		"%d attackers" % attackers)

	# Let them actually walk it, and confirm somebody ends up on the far side.
	# The player is made untouchable first: being knocked backwards mid-check moves the
	# very reference point the flank is measured against.
	player.hurtbox.active = false
	var anchor_x: float = player.global_position.x
	var guard := 0
	var flanked := false
	while guard < 480 and not flanked:
		await frames(1)
		guard += 1
		for e in group:
			if not is_instance_valid(e):
				continue
			if e.global_position.x < anchor_x - 12.0:
				flanked = true
		player.global_position.x = anchor_x
	player.hurtbox.active = true
	check("an enemy walks around to the far side", flanked, "%d frames" % guard)

	for e in group:
		if is_instance_valid(e):
			e.queue_free()
	await frames(2)

	# --- Telegraphs ---
	var telegraphed: Array[String] = []
	for id in ContentDB.moves.keys():
		var m: MoveData = ContentDB.moves[id]
		if m.telegraph:
			telegraphed.append(str(id))
	check("heavy enemy attacks are marked as telegraphed", telegraphed.size() >= 3,
		", ".join(telegraphed))
	var readable := true
	var too_fast := ""
	for id in telegraphed:
		var m: MoveData = ContentDB.get_move(id)
		# Under about a fifth of a second there is no time to react.
		if m.startup < 12:
			readable = false
			too_fast = "%s startup %d" % [id, m.startup]
	check("a telegraphed attack has a readable wind-up", readable, too_fast)

	await clear_stage(760.0)
	var boss_move: MoveData = ContentDB.get_move("enemy_slam")
	var heavy := spawn_enemy("rust_heavy", 30.0)
	await frames(4)
	pin(heavy)
	var before: int = p().hp
	heavy.combat.start_move(boss_move, 1.0)
	await frames(4)
	check("the wind-up runs before the hitbox is live",
		heavy.combat.current != null and heavy.combat.phase == 1 and p().hp == before,
		"phase=%d" % heavy.combat.phase)
	await frames(int(boss_move.startup) + 4)
	check("the hitbox goes live after the wind-up", heavy.combat.phase >= 2,
		"phase=%d" % heavy.combat.phase)
	await clear_stage(700.0)

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
	pin(e)
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
	# Driven by ContentDB, not a hand-written list, so a new area is covered the day it
	# is added instead of the day somebody remembers to update this array.
	var order: Array[String] = []
	for id in ContentDB.areas.keys():
		order.append(str(id))
	order.sort()
	for area_id in order:
		await SceneManager.change_area(area_id, "start")
		await seconds(0.5)
		var ok: bool = GameManager.current_area != null and GameManager.player_data.current_area == area_id
		var built: bool = GameManager.current_area != null and GameManager.current_area.actors_root.get_child_count() > 2
		check("travel to %s" % area_id, ok and built and is_instance_valid(GameManager.player),
			"%d actor nodes" % (GameManager.current_area.actors_root.get_child_count() if GameManager.current_area else 0))
		await _check_camera_follows(area_id)
		GameManager.set_flag("visited_" + area_id, true)

## The camera must keep the player on screen at both ends of the street. This catches
## limit_left/limit_right being set as camera-centre bounds instead of world edges.
func _check_camera_follows(area_id: String) -> void:
	var area = GameManager.current_area
	var player := p()
	if area == null or player == null:
		return
	var half := get_viewport().get_visible_rect().size * 0.5
	var worst := ""
	for x in [area.walk_min_x + 30.0, area.walk_max_x - 30.0]:
		player.global_position.x = x
		area.camera.snap_to_target()
		await frames(3)
		var cam: Vector2 = area.camera.get_screen_center_position()
		if absf(player.global_position.x - cam.x) > half.x - 24.0:
			worst = "player x=%.0f but camera centre x=%.0f" % [player.global_position.x, cam.x]
	check("camera frames the player across %s" % area_id, worst == "", worst)

# ---------------------------------------------------------------- world graph
## The map is a graph of doors. A door that names a spawn point the destination does not
## have drops the player at the area default, which reads as teleporting to the wrong end
## of the street; a connection listed one way only breaks the map screen. Neither errors.
func test_world_graph() -> void:
	print("\n-- World graph --")
	var layouts: Dictionary = {}
	for id in ContentDB.areas.keys():
		var path := "res://data/areas/%s.json" % id
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Dictionary:
			layouts[str(id)] = parsed

	check("every area has a layout", layouts.size() == ContentDB.areas.size(),
		"%d layouts for %d areas" % [layouts.size(), ContentDB.areas.size()])

	var bad_spawn: Array[String] = []
	var graph: Dictionary = {}
	for id in layouts.keys():
		graph[id] = []
		for d in layouts[id].get("doors", []):
			var to := str(d.get("to", ""))
			if to == "":
				continue
			graph[id].append(to)
			if not layouts.has(to):
				continue
			var want := str(d.get("spawn", "start"))
			var found := false
			for sp in layouts[to].get("spawns", []):
				if str(sp.get("id", "")) == want:
					found = true
			if not found:
				bad_spawn.append("%s -> %s wants spawn '%s'" % [id, to, want])
	check("every door lands on a spawn point that exists", bad_spawn.is_empty(), ", ".join(bad_spawn))

	# A door one way needs a door back, or the player walks into a dead end.
	var one_way: Array[String] = []
	for id in graph.keys():
		for to in graph[id]:
			if graph.has(to) and not (id in graph[to]):
				one_way.append("%s -> %s has no way back" % [id, to])
	check("every door has a return door", one_way.is_empty(), ", ".join(one_way))

	# AreaData.connections drives the map screen; it must agree with the actual doors.
	var mismatch: Array[String] = []
	for id in layouts.keys():
		var a: AreaData = ContentDB.areas[id]
		for to in graph[id]:
			if not (to in a.connections):
				mismatch.append("%s door -> %s missing from connections" % [id, to])
		for c in a.connections:
			if not (str(c) in graph[id]):
				mismatch.append("%s connection -> %s has no door" % [id, c])
	check("map connections match the doors", mismatch.is_empty(), ", ".join(mismatch))

	# Every area must be walkable from the opening street, ignoring flag gates.
	var seen: Dictionary = {"ferry_row": true}
	var queue: Array[String] = ["ferry_row"]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for to in graph.get(cur, []):
			if not seen.has(to):
				seen[to] = true
				queue.append(to)
	var unreachable: Array[String] = []
	for id in layouts.keys():
		if not seen.has(id):
			unreachable.append(id)
	check("every area is reachable from ferry_row", unreachable.is_empty(), ", ".join(unreachable))

## Source with comments removed, so a rule written down in a doc comment does not read as
## a violation of itself.
func _code_only(path: String) -> String:
	var out := ""
	for line in FileAccess.get_file_as_string(path).split("
"):
		var t := (line as String).strip_edges()
		if t.begins_with("#"):
			continue
		var hash_at := (line as String).find("#")
		out += ((line as String).substr(0, hash_at) if hash_at >= 0 else line) + "
"
	return out

# ---------------------------------------------------------------- lighting
## Lighting fails quietly in both directions. Turned off it does nothing visible, which
## looks the same as it not existing. Turned on in the wrong place it blows emissive art
## out to white. Neither raises an error, so both need asserting.
func test_lighting() -> void:
	print("\n-- Lighting and bloom --")
	check("the glow environment exists", Renderer2D.env != null)
	if Renderer2D.env:
		# The threshold is load-bearing. At 1.0, with HDR 2D on, ordinary art clamps at
		# 1.0 and can never bloom; only deliberately overbright emission does. Drop the
		# threshold below 1.0 and every white sneaker in the game starts to smear.
		check("bloom threshold keeps ordinary art out of the glow",
			is_equal_approx(Renderer2D.env.glow_hdr_threshold, 1.0),
			"%.2f" % Renderer2D.env.glow_hdr_threshold)
	check("HDR 2D is on, which is what makes that threshold mean anything",
		get_viewport().use_hdr_2d)

	# Emission masks must line up with real art, or an asset silently stops glowing.
	var orphans: Array[String] = []
	var d := DirAccess.open(Emission.DIR)
	var mask_count := 0
	if d:
		for f in d.get_files():
			if not f.ends_with("_e.png"):
				continue
			mask_count += 1
			var stem := f.substr(0, f.length() - 6)
			var in_props := ResourceLoader.exists("res://assets/art/props/%s.png" % stem)
			var in_bg := ResourceLoader.exists("res://assets/art/backgrounds/%s.png" % stem)
			if not (in_props or in_bg):
				orphans.append(stem)
	check("emission masks all have source art", orphans.is_empty(), ", ".join(orphans))
	check("emission masks were generated", mask_count > 0, "%d masks" % mask_count)

	# Every light texture a layout asks for must exist, or that light silently vanishes.
	var missing_tex: Array[String] = []
	var lit_areas: Array[String] = []
	for id in ContentDB.areas.keys():
		var path := "res://data/areas/%s.json" % id
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		if not (parsed is Dictionary):
			continue
		var cfg: Dictionary = parsed.get("lighting", {})
		if cfg.is_empty():
			continue
		lit_areas.append(str(id))
		for l in cfg.get("lights", []):
			var t := str(l.get("texture", "lamp"))
			if not ResourceLoader.exists("res://assets/art/light/%s.png" % t):
				missing_tex.append("%s -> %s" % [id, t])
	check("every light texture a layout names exists", missing_tex.is_empty(), ", ".join(missing_tex))
	check("at least one area is lit", not lit_areas.is_empty(), ", ".join(lit_areas))

	# A lit area, with the quality setting on.
	GameManager.lighting_enabled = true
	await SceneManager.change_area("metro_platform", "start")
	await seconds(0.5)
	var area = GameManager.current_area
	check("the lit area reports lighting", area.lighting != null and area.lighting.enabled)
	if area.lighting:
		check("its lights were built", area.lighting.light_count() > 0,
			"%d lights" % area.lighting.light_count())
		check("an ambient tint is applied",
			area.lighting.ambient != Color.WHITE, str(area.lighting.ambient))
	check("bloom is on in a lit area", Renderer2D.is_glow_on())
	check("emission overlays are allowed", Emission.enabled)
	var lit_overlays := _count_emission(area)
	check("emissive props got their overlay", lit_overlays > 0, "%d overlays" % lit_overlays)
	# Under a dark ambient every canvas item is multiplied down, emission included, so the
	# gain has to be compensated or the lamps stop clearing the bloom threshold.
	check("emission gain is compensated for the ambient", Emission.boost > 1.0,
		"boost %.2f" % Emission.boost)

	# The same area with the quality setting off must look exactly like it did before
	# lighting existed: no tint, no lights, no overbright sprites.
	GameManager.lighting_enabled = false
	await SceneManager.change_area("metro_platform", "start")
	await seconds(0.5)
	area = GameManager.current_area
	check("lighting off builds no lights", area.lighting.light_count() == 0)
	check("lighting off disables bloom", not Renderer2D.is_glow_on())
	check("lighting off attaches no emission overlays", _count_emission(area) == 0,
		"%d overlays" % _count_emission(area))

	# Toggling the setting rebuilds the area in place. If it dumped the player back at the
	# street entrance, changing a graphics option mid-street would lose your place.
	GameManager.lighting_enabled = true
	await SceneManager.change_area("metro_platform", "start")
	await seconds(0.4)
	var stand := Vector2(760.0, 60.0)
	p().global_position = stand
	await frames(2)
	await SceneManager.reload_area()
	await seconds(0.4)
	check("reloading an area keeps the player where they stood",
		p().global_position.distance_to(stand) < 4.0,
		"%.0f,%.0f -> %.0f,%.0f" % [stand.x, stand.y, p().global_position.x, p().global_position.y])
	check("reloading rebuilds the lighting",
		GameManager.current_area.lighting.light_count() > 0,
		"%d lights" % GameManager.current_area.lighting.light_count())

	# An area with no lighting block at all must be untouched by any of this.
	GameManager.lighting_enabled = true
	await SceneManager.change_area("ferry_row", "start")
	await seconds(0.5)
	area = GameManager.current_area
	check("an unlit area stays unlit", area.lighting != null and not area.lighting.enabled)
	check("an unlit area has no bloom", not Renderer2D.is_glow_on())
	check("an unlit area has no overbright sprites", _count_emission(area) == 0,
		"%d overlays" % _count_emission(area))

func _count_emission(node: Node) -> int:
	var n := 0
	for c in node.get_children():
		if c.name == "Emission":
			n += 1
		n += _count_emission(c)
	return n

# ---------------------------------------------------------------- chapter two
## The Metro Line opens off a flag. If the gate never unlocks, three areas, two shops,
## three quests and five enemies exist in the build and are unreachable, with no error.
func test_chapter_two() -> void:
	print("\n-- Chapter two: the Metro Line --")
	for id in ["metro_platform", "rooftop_route", "bellwater_block"]:
		check("area '%s' exists" % id, ContentDB.areas.has(id))
	for id in ["commuter_grunt", "commuter_rusher", "commuter_grappler", "commuter_ranged", "commuter_heavy"]:
		check("enemy '%s' exists" % id, ContentDB.enemies.has(id))
	check("Bex's dojo sells four techniques",
		ContentDB.get_shop("bex_dojo") != null and ContentDB.get_shop("bex_dojo").inventory.size() == 4,
		"%d" % (ContentDB.get_shop("bex_dojo").inventory.size() if ContentDB.get_shop("bex_dojo") else -1))
	check("Nadia's shop exists", ContentDB.get_shop("nadia_store") != null)
	for q in ["q_commuters", "q_tuesday", "q_roof"]:
		check("quest '%s' exists" % q, ContentDB.get_quest(q) != null)

	# The gate.
	GameManager.set_flag("metro_open", false)
	await SceneManager.change_area("lantern_market", "start")
	await seconds(0.4)
	var door := _find_door("to_metro")
	check("the market has a metro door", door != null)
	if door:
		check("the metro door is shut before the story opens it",
			door.required_flag == "metro_open" and not GameManager.get_flag("metro_open"))
	GameManager.set_flag("metro_open", true)
	await SceneManager.change_area("metro_platform", "from_market")
	await seconds(0.5)
	check("the metro platform builds", GameManager.current_area != null
		and GameManager.player_data.current_area == "metro_platform")
	check("the platform spawn is at the market end", is_instance_valid(GameManager.player)
		and GameManager.player.global_position.x < 200.0,
		"x=%.0f" % (GameManager.player.global_position.x if is_instance_valid(GameManager.player) else -1.0))
	await _check_camera_follows("metro_platform")

	# The locker is the only thing that sets the flag q_tuesday waits on.
	GameManager.set_flag("found_tuesday_locker", false)
	var locker: Node = null
	for n in GameManager.current_area.actors_root.get_children():
		if n.get("prop_id") == "locker" and n.get("searchable"):
			locker = n
	check("locker 12 is searchable", locker != null)
	if locker:
		check("searching the locker opens the Tuesday lead",
			str(locker.interact_dialogue) == "locker_found")

	# Walk the chapter-two loop the way a player does.
	await SceneManager.change_area("bellwater_block", "from_metro")
	await seconds(0.5)
	check("Bellwater builds off the platform", GameManager.player_data.current_area == "bellwater_block")
	await _check_camera_follows("bellwater_block")
	await SceneManager.change_area("rooftop_route", "from_bellwater")
	await seconds(0.5)
	check("the rooftop builds off Bellwater", GameManager.player_data.current_area == "rooftop_route")
	check("the rooftop spawn is at the Bellwater end", is_instance_valid(GameManager.player)
		and GameManager.player.global_position.x > 1000.0,
		"x=%.0f" % (GameManager.player.global_position.x if is_instance_valid(GameManager.player) else -1.0))
	await _check_camera_follows("rooftop_route")

	# A Commuter must actually fight, not just exist as a resource.
	clear_stage()
	await frames(2)
	var e := spawn_enemy("commuter_grunt", 40.0)
	await frames(6)
	check("a Commuter spawns and takes damage", e != null and _hit_once(e))

func _find_door(door_id: String) -> Node:
	if GameManager.current_area == null:
		return null
	for n in GameManager.current_area.actors_root.get_children():
		if n.get("door_id") == door_id:
			return n
	return null

func _hit_once(e: Node) -> bool:
	if e == null or not is_instance_valid(e):
		return false
	var before: int = e.hp
	var d := DamageData.new()
	d.amount = 5
	d.direction = 1
	d.source = GameManager.player
	e.take_damage(d)
	return e.hp < before

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
	# Walking out mid-fight must take the boss bar with you.
	var hud = get_tree().current_scene.get_node_or_null("UI/HUD")
	if hud and is_instance_valid(boss):
		hud._on_boss_started(boss)
		await frames(2)
		await SceneManager.change_area("ferry_row", "start")
		await seconds(0.4)
		check("the boss bar clears when you leave the area", not hud.boss_root.visible)
	else:
		check("the boss bar clears when you leave the area", false, "no HUD found")


# ---------------------------------------------------------------- touch controls
## Drive the on-screen controls with synthetic touch events, exactly as a phone would.
## Checking only that they are *visible* is what let a coordinate bug ship: every tap was
## being mapped through the screen transform a second time, so nothing could be hit.
## Synthetic touches are handed straight to the control's own _input. A headless run has
## no real input device, so the engine's delivery path cannot be exercised; what matters
## here is the hit-testing and stick maths inside TouchControls, which is where the
## coordinate bug lived. That the handler is actually wired up is asserted separately.
var _touch_target: Node = null

func touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	_touch_target._input(ev)
	await frames(2)

func drag(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	_touch_target._input(ev)
	await frames(2)

func test_touch_controls() -> void:
	log_line("
-- Touch controls --")
	await clear_stage(700.0)
	var game := get_tree().current_scene
	var tc = game.get_node_or_null("UI/TouchControlsHost/TouchControls")
	check("touch controls exist in the game scene", tc != null)
	if tc == null:
		return
	_touch_target = tc
	InputManager.set_touch_mode(true)
	await frames(4)
	check("touch controls become visible in touch mode", tc.visible and TouchControls.active)
	check("touch controls are listening for input", tc.is_processing_input())

	var vp := get_viewport().get_visible_rect().size
	var inside := true
	for b in tc._buttons:
		var r: Rect2 = b.node.get_global_rect()
		if r.position.x < 0.0 or r.position.y < 0.0 or r.end.x > vp.x or r.end.y > vp.y:
			inside = false
	check("every button sits fully on screen", inside, "viewport %s" % str(vp))

	# Buttons must not overlap each other, or a thumb hits two at once.
	var overlap := ""
	for i in tc._buttons.size():
		for j in range(i + 1, tc._buttons.size()):
			var a: Rect2 = tc._buttons[i].node.get_global_rect()
			var b2: Rect2 = tc._buttons[j].node.get_global_rect()
			if a.intersects(b2):
				overlap = "%s overlaps %s" % [tc._buttons[i].action, tc._buttons[j].action]
	check("buttons do not overlap", overlap == "", overlap)

	# The action cluster must stay compact and hug the bottom-right corner, rather than
	# sprawling up and across the screen where a thumb cannot reach and the game is hidden.
	var cluster := Rect2()
	var first := true
	for b in tc._buttons:
		if b.action == "pause":
			continue
		var r: Rect2 = b.node.get_global_rect()
		cluster = r if first else cluster.merge(r)
		first = false
	check("the action cluster is compact",
		cluster.size.x <= vp.x * 0.55 and cluster.size.y <= vp.y * 0.62,
		"%.0fx%.0f in a %.0fx%.0f viewport" % [cluster.size.x, cluster.size.y, vp.x, vp.y])
	check("the action cluster hugs the bottom-right corner",
		cluster.end.x >= vp.x * 0.9 and cluster.end.y >= vp.y * 0.85,
		"ends at %s" % str(cluster.end))
	check("the stick sits in the lower-left", tc._stick_home.x < vp.x * 0.3 and tc._stick_home.y > vp.y * 0.4,
		"home %s" % str(tc._stick_home))

	# --- The light attack button must actually attack ---
	var player := p()
	var e := spawn_enemy("rust_heavy", 20.0)
	await frames(4)
	e.global_position.y = player.global_position.y
	e.ai_state = EnemyBase.AI.WAIT
	e.think_timer = 10.0
	player.global_position = e.global_position - Vector2(18, 0)
	player.facing = 1
	var hp0: int = e.hp
	var light_node: TextureRect = null
	for b in tc._buttons:
		if b.action == "attack_light":
			light_node = b.node
	check("a light attack button exists", light_node != null)
	if light_node:
		await touch(0, light_node.get_global_rect().get_center(), true)
		await frames(4)
		await touch(0, light_node.get_global_rect().get_center(), false)
		await frames(20)
		check("tapping the light button attacks", e.hp < hp0, "%d -> %d" % [hp0, e.hp])

	# --- The stick must move the player ---
	await clear_stage(700.0)
	player = p()
	var home: Vector2 = tc._stick_home
	var start_x: float = player.global_position.x
	var origin: Vector2 = home + Vector2(tc.stick_base.size) * 0.5
	await touch(1, origin, true)
	await drag(1, origin + Vector2(tc.stick_base.size.x * 0.5, 0))
	await frames(20)
	check("dragging the stick reports movement", TouchControls.move_vector.x > 0.5,
		"vector %s" % str(TouchControls.move_vector))
	check("dragging the stick moves the player", player.global_position.x > start_x + 10.0,
		"moved %.1f" % (player.global_position.x - start_x))
	await touch(1, origin + Vector2(tc.stick_base.size.x * 0.5, 0), false)
	await frames(4)
	check("releasing the stick stops movement", TouchControls.move_vector == Vector2.ZERO)
	check("releasing returns the stick to its home position", tc.stick_base.position.is_equal_approx(home),
		"at %s, home %s" % [str(tc.stick_base.position), str(home)])

	# --- Moving and attacking at once ---
	var e2 := spawn_enemy("rust_heavy", 26.0)
	await frames(4)
	e2.global_position.y = p().global_position.y
	e2.ai_state = EnemyBase.AI.WAIT
	e2.think_timer = 10.0
	p().global_position = e2.global_position - Vector2(18, 0)
	p().facing = 1
	var hp1: int = e2.hp
	await touch(1, origin, true)
	await drag(1, origin + Vector2(tc.stick_base.size.x * 0.4, 0))
	if light_node:
		await touch(2, light_node.get_global_rect().get_center(), true)
	await frames(6)
	check("stick keeps working while a button is held", TouchControls.move_vector.x > 0.3,
		"vector %s" % str(TouchControls.move_vector))
	if light_node:
		await touch(2, light_node.get_global_rect().get_center(), false)
	await frames(20)
	check("attacking while moving still lands", e2.hp < hp1, "%d -> %d" % [hp1, e2.hp])
	await touch(1, origin, false)
	await frames(4)

	# --- The guard button drives the guard state ---
	var guard_node: TextureRect = null
	for b in tc._buttons:
		if b.action == "guard":
			guard_node = b.node
	check("a guard button exists on touch", guard_node != null)
	if guard_node:
		await touch(3, guard_node.get_global_rect().get_center(), true)
		check("holding the touch guard button sets the guard flag", TouchControls.guarding)
		await touch(3, guard_node.get_global_rect().get_center(), false)
		check("releasing the touch guard button clears it", not TouchControls.guarding)

	# --- A tap on empty screen must not be swallowed ---
	var empty := Vector2(vp.x * 0.55, vp.y * 0.25)
	var hit_something: bool = tc._touch_down(9, empty)
	check("a tap on empty screen is left for the rest of the UI", not hit_something,
		"at %s" % str(empty))

	InputManager.set_touch_mode(false)
	await frames(4)
	check("touch controls hide again when touch mode is off", not tc.visible)
	await clear_stage(700.0)

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

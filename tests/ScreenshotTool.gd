extends Node
## Visual capture pass. Run with a real (non-headless) renderer:
##   godot --path . --resolution 1280x720 -- --shots
##
## Loads the title screen and every area, stages a few gameplay moments, and writes PNGs
## to user://shots/ so the presentation can be reviewed without playing by hand.

const SHOT_DIR := "user://shots/"

var index: int = 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	# Wipe previous output; shot numbering shifts between runs.
	var d := DirAccess.open(SHOT_DIR)
	if d:
		for f in d.get_files():
			d.remove(f)
	print("[shots] writing to ", ProjectSettings.globalize_path(SHOT_DIR))
	await get_tree().process_frame
	await run()
	print("[shots] done")
	get_tree().quit(0)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	index += 1
	var path := SHOT_DIR + "%02d_%s.png" % [index, name]
	img.save_png(path)
	print("[shots] ", path)

func run() -> void:
	# --- Title ---
	SceneManager.goto_title()
	await seconds(1.2)
	await shot("title")

	# --- Start a game ---
	GameManager.new_game()
	GameManager.set_flag("seen_intro", true)
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")
	await seconds(1.6)
	GameManager.set_state(GameManager.State.PLAYING)
	await seconds(0.4)
	await shot("ferry_row_start")

	var player: Player = GameManager.player
	if player == null:
		push_error("[shots] no player")
		return

	# --- Walk down the street ---
	player.global_position.x = 620.0
	GameManager.current_area.camera.snap_to_target()
	await seconds(0.5)
	await shot("ferry_row_street")

	# --- A fight in progress ---
	await _stage_fight(["pigeon_grunt", "pigeon_grunt", "pigeon_rusher"], 700.0)
	await seconds(0.8)
	await shot("combat_crowd")
	player.facing = 1
	player._press_attack(MoveData.InputKind.LIGHT)
	await frames(8)
	await shot("combat_punch")
	player.combat.cancel()
	player.set_state(Actor.State.IDLE)
	player.energy = player.max_energy
	player._press_attack(MoveData.InputKind.HEAVY)
	await frames(12)
	await shot("combat_heavy")

	# --- Weapon ---
	_clear_enemies()
	await seconds(0.3)
	player.give_weapon("bat")
	await _stage_fight(["sweater_grunt"], player.global_position.x + 30.0)
	await frames(6)
	player.facing = 1
	player._press_attack(MoveData.InputKind.LIGHT)
	await frames(9)
	await shot("combat_weapon")

	# --- HUD extras: money, level, notification ---
	_clear_enemies()
	GameManager.add_money(250)
	GameManager.notify("Found $250", "item")
	await seconds(0.5)
	await shot("hud")

	# --- Dialogue ---
	DialogueManager.start("mae_intro")
	await seconds(1.4)
	await shot("dialogue")
	if DialogueManager.is_active():
		DialogueManager._finish()
	await frames(4)

	# --- Shop ---
	ShopManager.open_shop("mae_noodles")
	await seconds(0.8)
	await shot("shop_restaurant")
	ShopManager._ui.close()
	await frames(6)
	ShopManager.open_shop("odell_dojo")
	await seconds(0.6)
	await shot("shop_dojo")
	ShopManager._ui.close()
	await frames(6)

	# --- Pause menu pages ---
	var game := get_tree().current_scene
	game.pause_menu.open()
	await seconds(0.5)
	await shot("pause_stats")
	game.pause_menu._show_page(game.pause_menu.Page.TECHNIQUES)
	await seconds(0.3)
	await shot("pause_techniques")
	# Visit a few places first, or the map is a page of unknowns.
	for a in ["ferry_row", "lantern_market", "grease_alley", "metro_platform", "bellwater_block"]:
		GameManager.set_flag("visited_" + a, true)
	game.pause_menu._show_page(game.pause_menu.Page.MAP)
	await seconds(0.6)
	await shot("pause_map")
	game.pause_menu._show_page(game.pause_menu.Page.SAVES)
	await seconds(0.4)
	await shot("pause_saves")
	game.pause_menu._show_page(game.pause_menu.Page.SETTINGS)
	await seconds(0.4)
	await shot("pause_settings")
	# Focused inside the panel, which is the state that used to be unreachable.
	game.pause_menu.buttons[0].grab_focus()
	await frames(2)
	game.pause_menu._enter_page()
	await seconds(0.3)
	await shot("pause_settings_focused")
	game.pause_menu.close()
	await frames(6)

	# --- Touch controls ---
	InputManager.set_touch_mode(true)
	await seconds(0.6)
	await shot("touch_controls")
	InputManager.set_touch_mode(false)
	await frames(6)

	# --- Every area ---
	GameManager.set_flag("metro_open", true)
	GameManager.set_flag("bellwater_cleared", true)
	GameManager.set_flag("seen_line_office", true)   # skip the cutscene for a clean shot
	for area_id in ["lantern_market", "grease_alley", "rustpile_yard",
			"metro_platform", "rooftop_route", "bellwater_block", "line_office"]:
		await SceneManager.change_area(area_id, "start")
		await seconds(0.8)
		GameManager.player.global_position.x += 320.0
		GameManager.current_area.camera.snap_to_target()
		await seconds(0.5)
		await shot(area_id)

	# --- The fire escape, which is the whole point of having drawn one ---
	await SceneManager.change_area("grease_alley", "start")
	await seconds(0.8)
	# An encounter starts as soon as the player is in the street, and a running fight locks
	# the camera to its arena. The first attempts at this shot framed the subject off the
	# right edge with the camera pinned 250 px behind the player, which looked like a
	# camera bug and was a fight nobody had noticed starting.
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	GameManager.current_area.director._finish()
	GameManager.current_area.camera.unlock()
	for t in GameManager.current_area._encounter_triggers:
		t.fired = true
	await frames(2)
	GameManager.player.global_position.x = 743.0
	await seconds(1.2)
	await shot("fire_escape")

	# --- Boss ---
	GameManager.set_flag("yard_cleared", true)
	await SceneManager.change_area("starch_laundromat", "start")
	await seconds(0.8)
	GameManager.player.global_position.x = 860.0
	GameManager.current_area.camera.snap_to_target()
	await seconds(0.4)
	var enc: EncounterData = ContentDB.get_encounter("boss_starch")
	GameManager.set_flag("enc_boss_starch", false)
	GameManager.current_area.director.start_encounter(enc)
	var guard := 0
	while get_tree().get_nodes_in_group("bosses").is_empty() and guard < 400:
		if DialogueManager.is_active() and DialogueManager._box:
			if guard == 20:
				await shot("boss_intro_dialogue")
			DialogueManager._box._typing = false
			DialogueManager._box.line_finished.emit()
		await frames(2)
		guard += 1
	await seconds(2.2)
	await shot("boss_fight")

	# --- A Commuter fight, so chapter two is reviewed as well as chapter one ---
	await SceneManager.change_area("bellwater_block", "start")
	await seconds(0.8)
	_clear_enemies()
	await _stage_fight(["commuter_grunt", "commuter_rusher", "commuter_heavy"], 700.0)
	await seconds(0.9)
	await shot("commuter_fight")
	ShopManager.open_shop("bex_dojo")
	await seconds(0.7)
	await shot("shop_bex_dojo")
	ShopManager._ui.close()
	await frames(6)

func _clear_enemies() -> void:
	for n in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(n):
			n.queue_free()

func _stage_fight(ids: Array, x: float) -> void:
	var area = GameManager.current_area
	var player: Player = GameManager.player
	player.global_position.x = x
	area.camera.snap_to_target()
	for i in ids.size():
		var edata: EnemyData = ContentDB.get_enemy(str(ids[i]))
		if edata == null:
			continue
		var e = load("res://actors/enemies/Enemy.tscn").instantiate()
		e.data = edata
		area.actors_root.add_child(e)
		e.global_position = Vector2(x + 34.0 + i * 26.0, area.lane_min + 6.0 + i * 12.0)
		e.set_lane_bounds(area.lane_min, area.lane_max, area.walk_min_x, area.walk_max_x)
		e.aggro = true
	await frames(4)

extends CanvasLayer
## Handles high-level scene flow (boot -> title -> game) and area transitions with a fade.

const TITLE_SCENE := "res://ui/title/TitleScreen.tscn"
const GAME_SCENE := "res://scenes/game/Game.tscn"
const AREA_DIR := "res://world/areas/"

var _fade: ColorRect
var _busy: bool = false
var game_root: Node = null

## Fade state. This is stepped by hand rather than with a Tween: the fade gates scene
## flow, and a tween that fails to finish would leave the game stuck behind a black
## rectangle with no way out.
var _fade_target: float = 1.0
var _fade_speed: float = 3.0

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color(0.03, 0.02, 0.05, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 1.0
	add_child(_fade)

func _process(delta: float) -> void:
	if _fade == null:
		return
	var a := _fade.modulate.a
	if is_equal_approx(a, _fade_target):
		return
	# Unscaled: slow motion and hit stop must not stall a screen transition.
	var step := _fade_speed * (delta / maxf(Engine.time_scale, 0.0001))
	_fade.modulate.a = move_toward(a, _fade_target, step)

func _fade_to(target: float, duration: float) -> void:
	_fade_target = clampf(target, 0.0, 1.0)
	_fade_speed = 1.0 / maxf(duration, 0.01)
	# Bounded: a transition must never be able to trap the player behind the overlay.
	var guard := 0
	while not is_equal_approx(_fade.modulate.a, _fade_target) and guard < 600:
		await get_tree().process_frame
		guard += 1
	_fade.modulate.a = _fade_target

func fade_out(duration: float = 0.35) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0, duration)

func fade_in(duration: float = 0.35) -> void:
	await _fade_to(0.0, duration)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Screen dimming state, for tests and for anything that needs to know a transition is up.
func fade_alpha() -> float:
	return _fade.modulate.a if _fade else 0.0

func is_busy() -> bool:
	return _busy

func goto_title() -> void:
	if _busy:
		return
	_busy = true
	GameManager.clear_time_effects()
	await fade_out()
	get_tree().paused = false
	GameManager.set_state(GameManager.State.TITLE)
	game_root = null
	GameManager.player = null
	GameManager.current_area = null
	get_tree().change_scene_to_file(TITLE_SCENE)
	await get_tree().process_frame
	await fade_in()
	_busy = false

func start_new_game() -> void:
	if _busy:
		return
	GameManager.new_game()
	await _enter_game()

func continue_game(slot: int = 0) -> void:
	if _busy:
		return
	if not SaveManager.load_game(slot):
		GameManager.notify("No save found", "error")
		return
	await _enter_game()

func _enter_game() -> void:
	_busy = true
	await fade_out()
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE)
	await get_tree().process_frame
	await get_tree().process_frame
	_busy = false
	# Game.gd loads the current area and fades in when ready.

## Travel to another area. spawn_id names a SpawnPoint inside that area.
func change_area(area_id: String, spawn_id: String = "start") -> void:
	if _busy or game_root == null:
		return
	_busy = true
	GameManager.clear_time_effects()
	await fade_out(0.3)
	await game_root.load_area(area_id, spawn_id)
	await fade_in(0.3)
	_busy = false
	# Entry events run here, after the fade, for every area the player walks into.
	#
	# They used to run only in Game._ready(), which means only for whichever area the game
	# booted into -- so no area's on_enter ever fired during actual play. The Line Office
	# arrival is what sets chapter_2_done, so walking in did nothing and chapter two could
	# not be completed. Nothing errored: you simply stood in an empty office.
	if game_root.area and is_instance_valid(game_root.area):
		game_root.area.run_entry_events()

## Rebuild the current area in place, keeping the player where they were standing.
## Used when a setting changes what an area is made of, such as lighting, so the change is
## visible immediately without dumping the player back at the street entrance.
func reload_area() -> void:
	var area_id: String = GameManager.player_data.current_area
	if area_id == "" or _busy or game_root == null:
		return
	var keep := Vector2.ZERO
	var had_player := is_instance_valid(GameManager.player)
	if had_player:
		keep = GameManager.player.global_position
	_busy = true
	GameManager.clear_time_effects()
	await fade_out(0.2)
	await game_root.load_area(area_id, "start")
	if had_player and is_instance_valid(GameManager.player):
		GameManager.player.global_position = keep
		var area = GameManager.current_area
		if area and area.camera:
			area.camera.snap_to_target()
	await fade_in(0.2)
	_busy = false

func area_scene_path(area_id: String) -> String:
	return AREA_DIR + area_id + ".tscn"

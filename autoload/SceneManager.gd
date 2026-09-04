extends CanvasLayer
## Handles high-level scene flow (boot -> title -> game) and area transitions with a fade.

const TITLE_SCENE := "res://ui/title/TitleScreen.tscn"
const GAME_SCENE := "res://scenes/game/Game.tscn"
const AREA_DIR := "res://world/areas/"

var _fade: ColorRect
var _busy: bool = false
var game_root: Node = null

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color(0.03, 0.02, 0.05, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 1.0
	add_child(_fade)

func fade_out(duration: float = 0.35) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(_fade, "modulate:a", 1.0, duration)
	await tw.finished

func fade_in(duration: float = 0.35) -> void:
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(_fade, "modulate:a", 0.0, duration)
	await tw.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

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

func area_scene_path(area_id: String) -> String:
	return AREA_DIR + area_id + ".tscn"

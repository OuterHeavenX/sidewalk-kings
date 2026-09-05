extends Node2D
## Gameplay root: owns the camera, the current Area, the player, the HUD and the pause menu.
## SceneManager talks to this node to change areas.

const PLAYER_SCENE := "res://actors/player/Player.tscn"
const AREA_SCENE := "res://world/Area.tscn"

@onready var world: Node2D = $World
@onready var camera: GameCamera = $Camera
@onready var ui_layer: CanvasLayer = $UI
@onready var hud: Node = $UI/HUD
@onready var pause_menu: Node = $UI/PauseMenu
@onready var touch: Node = $UI/TouchControlsHost/TouchControls
@onready var debug_panel: Node = $UI/DebugPanel

var area: Area = null
var player: Player = null
var _respawning: bool = false

func _ready() -> void:
	FX.setup(world)
	SceneManager.game_root = self
	GameManager.current_area = null
	EventBus.player_died.connect(_on_player_died)
	if debug_panel:
		debug_panel.visible = false
	await get_tree().process_frame
	await load_area(GameManager.player_data.current_area, GameManager.player_data.current_spawn)
	GameManager.set_state(GameManager.State.PLAYING)
	await SceneManager.fade_in(0.45)
	if area:
		area.run_entry_events()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and GameManager.state in [GameManager.State.PLAYING, GameManager.State.PAUSED]:
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_toggle") and GameManager.debug_enabled and debug_panel:
		debug_panel.visible = not debug_panel.visible
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	if DialogueManager.is_active() or ShopManager.is_open():
		return
	if GameManager.state == GameManager.State.PAUSED:
		pause_menu.close()
	else:
		pause_menu.open()

## Tear down the current area and build the requested one. Called by SceneManager.
func load_area(area_id: String, spawn_id: String = "start") -> void:
	EventBus.area_loading.emit(area_id)
	if area and is_instance_valid(area):
		if area.director:
			area.director.abort()
		area.queue_free()
		area = null
		await get_tree().process_frame
	if is_instance_valid(player):
		player.sync_to_data()
		player.queue_free()
		player = null
		await get_tree().process_frame

	var scene: PackedScene = load(AREA_SCENE)
	area = scene.instantiate()
	world.add_child(area)
	area.build(area_id, camera)
	GameManager.current_area = area
	GameManager.player_data.current_area = area_id
	GameManager.player_data.current_spawn = spawn_id

	# Player
	var pscene: PackedScene = load(PLAYER_SCENE)
	player = pscene.instantiate()
	area.actors_root.add_child(player)
	player.global_position = area.get_spawn(spawn_id)
	player.set_lane_bounds(area.lane_min, area.lane_max, area.walk_min_x, area.walk_max_x)
	if GameManager.player_data.equipped_weapon != "":
		player.give_weapon(GameManager.player_data.equipped_weapon)

	# Camera2D limits are world edges, not bounds on the camera centre.
	camera.setup(player, area.walk_min_x - 20.0, area.walk_max_x + 20.0, area.camera_y)
	camera.snap_to_target()

	# Record the visit. The map has always read this flag and nothing has ever written it,
	# so every area showed as unknown no matter how far you had walked.
	GameManager.set_flag("visited_" + area_id, true)

	var meta: AreaData = ContentDB.get_area(area_id)
	if meta:
		AudioManager.play_music(meta.music)
		AudioManager.play_ambience(meta.ambience)
		EventBus.area_entered.emit(area_id, meta.display_name)
		GameManager.notify(meta.display_name, "area")
	else:
		EventBus.area_entered.emit(area_id, area_id.capitalize())
	_respawning = false

func _on_player_died() -> void:
	if _respawning:
		return
	_respawning = true
	EventBus.slow_motion.emit(0.4, 1.0)
	await get_tree().create_timer(2.0).timeout
	GameManager.clear_time_effects()
	GameManager.set_state(GameManager.State.GAME_OVER)
	await SceneManager.fade_out(0.5)
	# Classic beat-em-up handling: lose some cash, wake up back at the area entrance.
	var lost := int(GameManager.player_data.money * 0.25)
	if lost > 0:
		GameManager.add_money(-lost)
	var pd := GameManager.player_data
	pd.hp = maxi(1, int(pd.get_max_hp() * 0.6))
	if area and area.director:
		area.director.abort()
	await load_area(pd.current_area, pd.current_spawn)
	GameManager.set_state(GameManager.State.PLAYING)
	EventBus.player_respawned.emit()
	if lost > 0:
		GameManager.notify("You woke up in an alley. Lost $%d." % lost, "warn")
	await SceneManager.fade_in(0.5)
	_respawning = false

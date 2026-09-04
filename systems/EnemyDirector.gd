class_name EnemyDirector
extends Node
## Runs encounters: spawns waves from EncounterData, enforces the on-screen enemy cap,
## sends reinforcements as the player thins the crowd, and reports when a fight is cleared.
##
## Spawn data lives in EncounterData resources, never in enemy code.

signal encounter_cleared(encounter_id: String)

const ENEMY_SCENE := "res://actors/enemies/Enemy.tscn"
const BOSS_SCENE := "res://actors/bosses/Boss.tscn"

var area: Node = null
var active_encounter: EncounterData = null
var alive: Array[Node] = []
var queue: Array[Dictionary] = []
var spawned_total: int = 0
var _spawn_timer: float = 0.0
var _running: bool = false
var _cleared_ids: Array[String] = []

func setup(area_node: Node) -> void:
	area = area_node

func is_running() -> bool:
	return _running

func start_encounter(enc: EncounterData) -> void:
	if _running or enc == null:
		return
	if enc.once_flag != "" and GameManager.get_flag(enc.once_flag):
		return
	if enc.id in _cleared_ids and not enc.respawn_on_reenter:
		return
	active_encounter = enc
	_running = true
	alive.clear()
	queue.clear()
	spawned_total = 0
	for wave in enc.waves:
		var count := int(wave.get("count", 1))
		for i in count:
			queue.append({"enemy": str(wave.get("enemy", "")), "side": str(wave.get("side", "any")),
				"delay": float(wave.get("delay", 0.0)), "boss": bool(wave.get("boss", false))})
	EventBus.encounter_started.emit(enc.id)
	if enc.music != "":
		AudioManager.play_music(enc.music)
	if area and area.has_method("lock_camera") and enc.lock_camera:
		area.lock_camera(true)
	if enc.intro_dialogue != "":
		DialogueManager.start(enc.intro_dialogue, "", func(): _spawn_timer = 0.15)
	else:
		_spawn_timer = 0.25

func _physics_process(delta: float) -> void:
	if not _running or GameManager.is_frozen():
		return
	alive = alive.filter(func(e): return is_instance_valid(e) and not e.dead)
	if _spawn_timer > 0.0:
		_spawn_timer -= delta
		return
	var cap := active_encounter.max_active
	if not queue.is_empty() and alive.size() < cap and GameManager.is_gameplay_active():
		var entry: Dictionary = queue.pop_front()
		_spawn(entry)
		_spawn_timer = maxf(0.35, float(entry.get("delay", 0.0)))
		return
	if queue.is_empty() and alive.is_empty():
		_finish()

func _spawn(entry: Dictionary) -> void:
	var eid := str(entry["enemy"])
	var edata: EnemyData = ContentDB.get_enemy(eid)
	if edata == null:
		push_warning("[EnemyDirector] unknown enemy '%s'" % eid)
		return
	var is_boss: bool = bool(entry.get("boss", false)) or edata.archetype == EnemyData.Archetype.BOSS
	var scene: PackedScene = load(BOSS_SCENE if is_boss else ENEMY_SCENE)
	var e = scene.instantiate()
	e.data = edata
	e.level_scale = 1.0 + (GameManager.player_data.level - 1) * active_encounter.difficulty_scale_per_level
	if is_boss:
		e.boss_id = active_encounter.boss_id if active_encounter.boss_id != "" else eid
	var container: Node = area.actors_root if area and area.get("actors_root") != null else area
	container.add_child(e)
	e.global_position = _spawn_position(str(entry.get("side", "any")))
	e.set_lane_bounds(area.lane_min, area.lane_max, area.walk_min_x, area.walk_max_x)
	e.slot_index = spawned_total
	spawned_total += 1
	alive.append(e)
	e.defeated.connect(_on_enemy_defeated)
	EventBus.enemy_spawned.emit(e)
	if is_boss:
		e.start_fight()
	# Walk-in from off-screen so fights start with movement, not a pop-in.
	e.play_anim("walk")

func _spawn_position(side: String) -> Vector2:
	var p := GameManager.player
	var cam_x: float = p.global_position.x if is_instance_valid(p) else 0.0
	var half := 180.0
	var s := side
	if s == "any":
		s = "left" if randf() < 0.5 else "right"
	var x := cam_x + (half + randf_range(6.0, 40.0)) * (1.0 if s == "right" else -1.0)
	x = clampf(x, area.walk_min_x + 6.0, area.walk_max_x - 6.0)
	var y := randf_range(area.lane_min + 4.0, area.lane_max - 4.0)
	return Vector2(x, y)

func _on_enemy_defeated(_e: Node) -> void:
	pass

func _finish() -> void:
	_running = false
	var enc := active_encounter
	active_encounter = null
	if enc == null:
		return
	if not (enc.id in _cleared_ids):
		_cleared_ids.append(enc.id)
	if enc.once_flag != "":
		GameManager.set_flag(enc.once_flag, true)
	if enc.reward_flag != "":
		GameManager.set_flag(enc.reward_flag, true)
	if area and area.has_method("lock_camera"):
		area.lock_camera(false)
	EventBus.encounter_cleared.emit(enc.id)
	encounter_cleared.emit(enc.id)
	if area and area.has_method("on_encounter_cleared"):
		area.on_encounter_cleared(enc.id)
	if enc.clear_dialogue != "":
		await get_tree().create_timer(0.6).timeout
		DialogueManager.start(enc.clear_dialogue)

func abort() -> void:
	_running = false
	queue.clear()
	for e in alive:
		if is_instance_valid(e):
			e.queue_free()
	alive.clear()
	active_encounter = null

## Debug helper: drop a single enemy next to the player.
func debug_spawn(enemy_id: String) -> void:
	var edata: EnemyData = ContentDB.get_enemy(enemy_id)
	if edata == null:
		return
	var scene: PackedScene = load(ENEMY_SCENE)
	var e = scene.instantiate()
	e.data = edata
	var container: Node = area.actors_root if area and area.get("actors_root") != null else area
	container.add_child(e)
	var p := GameManager.player
	e.global_position = (p.global_position if is_instance_valid(p) else Vector2.ZERO) + Vector2(60, 0)
	e.set_lane_bounds(area.lane_min, area.lane_max, area.walk_min_x, area.walk_max_x)

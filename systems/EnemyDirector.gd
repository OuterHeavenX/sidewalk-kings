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
var _slot_timer: float = 0.0

## How many enemies may hold an attacking slot at once. The rest flank or wait, which is
## what keeps a crowd readable instead of a pile-on.
const ATTACK_SLOTS := 2
const SLOT_INTERVAL := 0.6

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
	if GameManager.is_frozen():
		return
	_slot_timer -= delta
	if _slot_timer <= 0.0:
		_slot_timer = SLOT_INTERVAL
		assign_slots()
	if not _running:
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
	# An enemy spawned into a running encounter is already in the fight, so it does not wait
	# to notice the player.
	#
	# Aggro range is 190px, which is right for someone loitering on a street and wrong for
	# someone the director just sent to attack. Walk away mid-encounter and the spawns sit
	# idle at the far end forever: the fight never ends, so the camera stays locked, the
	# battle music keeps playing and fast travel keeps refusing, with nothing on screen to
	# say the area still thinks you are fighting. The playthrough found it stranded 900px
	# from three Pigeons who had never looked up.
	e.call_deferred("_become_aggro")
	e.defeated.connect(_on_enemy_defeated)
	EventBus.enemy_spawned.emit(e)
	_slot_timer = 0.0
	if is_boss:
		e.start_fight()
	# Walk-in from off-screen so fights start with movement, not a pop-in.
	e.play_anim("walk")

## Hand out engagement roles and approach sides.
##
## Enemies are split across both sides of the player rather than queuing up on whichever
## side they spawned. Only ATTACK_SLOTS of them may commit to an attack at a time; the rest
## circle round or hold back, so a group reads as a crowd surrounding you instead of a
## line waiting its turn.
func assign_slots() -> void:
	var player := GameManager.player
	if not is_instance_valid(player):
		return
	var fighters: Array[Node] = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and e.get("role") != null:
			fighters.append(e)
	if fighters.is_empty():
		return

	# Nearest first: whoever is already closest earns the right to engage.
	var px: float = player.global_position.x
	fighters.sort_custom(func(a, b):
		return absf(a.global_position.x - px) < absf(b.global_position.x - px))

	# Sides are sticky. Recomputing them from current positions every cycle would send an
	# enemy that is halfway around the player straight back again, because crossing makes it
	# the nearest one; it would pace on the spot forever.
	var left: Array = []
	var right: Array = []
	var unassigned: Array = []
	for e in fighters:
		if e.desired_side < 0:
			left.append(e)
		elif e.desired_side > 0:
			right.append(e)
		else:
			unassigned.append(e)

	# New arrivals fill the lighter side, breaking ties toward the side they are already on.
	for e in unassigned:
		var side: int
		if left.size() < right.size():
			side = -1
		elif right.size() < left.size():
			side = 1
		else:
			side = 1 if e.global_position.x >= px else -1
		e.desired_side = side
		(right if side > 0 else left).append(e)

	# Rebalance only when the split is genuinely lopsided, and move whoever has the least
	# invested in their current position: the one furthest from the player.
	while absi(left.size() - right.size()) > 1:
		var heavy: Array = left if left.size() > right.size() else right
		var light: Array = right if left.size() > right.size() else left
		heavy.sort_custom(func(a, b):
			return absf(a.global_position.x - px) > absf(b.global_position.x - px))
		var mover = heavy.pop_front()
		mover.desired_side = -1 if light == left else 1
		light.append(mover)

	for i in fighters.size():
		var f = fighters[i]
		f.slot_index = i
		if i < ATTACK_SLOTS:
			f.role = EnemyBase.Role.ATTACKER
		elif i < ATTACK_SLOTS + 2:
			f.role = EnemyBase.Role.FLANKER
		else:
			f.role = EnemyBase.Role.WAITING
		# A newly reassigned enemy should reconsider promptly.
		if f.think_timer > 0.35:
			f.think_timer = 0.2

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

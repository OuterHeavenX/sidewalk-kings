class_name CombatController
extends Node
## Drives data-driven moves for any Actor: startup -> active -> recovery, with combo
## cancel windows. Moves are MoveData resources, so new attacks are new .tres files.

signal move_started(move: MoveData)
signal move_hit(target: Node, move: MoveData)
signal move_finished(move: MoveData)

var actor: Actor = null
var hitbox: Hitbox = null
var current: MoveData = null
var frame: int = 0
var phase: int = 0                # 0 idle, 1 startup, 2 active, 3 recovery
var buffered_input: String = ""
var buffer_frames: int = 0
var did_hit: bool = false
var cancel_ready: bool = false
var damage_multiplier_provider: Callable = Callable()
var combo_count: int = 0
var _combo_reset_frames: int = 0

const BUFFER_WINDOW := 9

func setup(a: Actor, hb: Hitbox) -> void:
	actor = a
	hitbox = hb
	hitbox.hit_target.connect(_on_hit)

func is_busy() -> bool:
	return current != null

func can_cancel() -> bool:
	return current != null and cancel_ready

func buffer(input_name: String) -> void:
	buffered_input = input_name
	buffer_frames = BUFFER_WINDOW

## Start a move immediately. Returns false if the move can't be used.
func start_move(move: MoveData, multiplier: float = 1.0) -> bool:
	if move == null or actor == null or actor.dead:
		return false
	current = move
	frame = 0
	phase = 1
	did_hit = false
	cancel_ready = false
	_combo_reset_frames = 60
	combo_count += 1
	var dmg := DamageData.from_move(move, actor, actor.facing, multiplier)
	if actor.is_player:
		var pd := GameManager.player_data
		if randf() < pd.get_crit_chance():
			dmg.crit = true
			dmg.amount = int(dmg.amount * 1.6)
			dmg.hit_sound = "hit_crit"
			dmg.screen_shake = maxf(dmg.screen_shake, 3.0)
	hitbox.configure(move, actor.facing, dmg, actor)
	actor.play_anim(move.animation, true, true)
	if move.sound != "":
		AudioManager.play_sfx(move.sound, -4.0)
	if move.self_launch > 0.0:
		actor.z_velocity = move.self_launch
	move_started.emit(move)
	return true

func _physics_process(_delta: float) -> void:
	if GameManager.is_frozen():
		return
	if buffer_frames > 0:
		buffer_frames -= 1
		if buffer_frames <= 0:
			buffered_input = ""
	if _combo_reset_frames > 0:
		_combo_reset_frames -= 1
		if _combo_reset_frames <= 0:
			combo_count = 0
	if current == null:
		return
	frame += 1
	match phase:
		1:
			if current.forward_move != 0.0 and actor:
				actor.knockback_velocity.x = current.forward_move * actor.facing
			if frame >= current.startup:
				phase = 2
				frame = 0
				hitbox.activate()
		2:
			if frame >= current.active:
				phase = 3
				frame = 0
				hitbox.deactivate()
		3:
			if did_hit and frame <= current.cancel_window:
				cancel_ready = true
			if frame >= current.recovery:
				_finish()

func _finish() -> void:
	var m := current
	current = null
	phase = 0
	frame = 0
	cancel_ready = false
	hitbox.deactivate()
	if actor and actor.state == Actor.State.ATTACK:
		actor.set_state(Actor.State.IDLE)
	move_finished.emit(m)

func cancel() -> void:
	if current != null:
		_finish()

func _on_hit(target: Node, dmg: DamageData) -> void:
	did_hit = true
	cancel_ready = true
	move_hit.emit(target, current)
	if current.hit_pause > 0.0:
		EventBus.hit_stop.emit(current.hit_pause)
	if current.screen_shake > 0.0:
		EventBus.screen_shake.emit(current.screen_shake, 0.18)
	EventBus.hit_landed.emit(actor, target, dmg.amount, dmg.heavy)

## Look through the current move's followups for one matching the pressed input.
func find_followup(input_kind: int) -> MoveData:
	if current == null:
		return null
	for mid in current.followups:
		var m: MoveData = ContentDB.get_move(mid)
		if m == null:
			continue
		if m.input != input_kind:
			continue
		if actor.is_player and not GameManager.has_move(mid):
			continue
		return m
	return null

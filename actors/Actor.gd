class_name Actor
extends CharacterBody2D
## Shared base for every fighter (player, enemies, bosses).
##
## Coordinate system: position.x runs along the street, position.y is depth within the
## walkable lane (used for Y-sorting), and z_height lifts the sprite off the ground for
## jumps and launches. Gravity is applied to z_height only.

signal state_changed(new_state: int)
signal defeated(actor: Node)

enum State { IDLE, WALK, RUN, ATTACK, HURT, KNOCKDOWN, GETUP, GRABBING, GRABBED, JUMP, DEFEATED, SPAWNING, STUNNED, DIALOGUE, GUARD, DODGE }

const GRAVITY := 620.0
const LANE_SORT_SCALE := 1.0

@export var max_hp: int = 30
@export var move_speed: float = 80.0
@export var run_speed: float = 140.0
@export var weight: float = 1.0
@export var lane_speed_ratio: float = 0.62      # vertical movement is slower, classic beat-em-up feel
@export var body_radius: float = 7.0

var hp: int = 30
var state: State = State.IDLE
var facing: int = 1
var z_height: float = 0.0
var z_velocity: float = 0.0
var move_input: Vector2 = Vector2.ZERO
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_z: float = 0.0
var hitstun_frames: int = 0
var invuln_frames: int = 0
var is_player: bool = false
var team: int = 0                                # 0 = player side, 1 = enemies
var lane_min: float = 0.0
var lane_max: float = 0.0
var bounds_min: float = -1e9
var bounds_max: float = 1e9
var can_be_grabbed: bool = true
var grabbed_by: Node = null
var grabbing: Node = null
var armor_threshold: int = 0
var flash_time: float = 0.0
var dead: bool = false

@onready var sprite: AnimatedSprite2D = $Visual/Sprite
@onready var visual: Node2D = $Visual
@onready var shadow: Sprite2D = $Shadow
@onready var hurtbox: Hurtbox = $Hurtbox

var _anim_lock: bool = false
var _current_anim: String = ""

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	hp = max_hp
	if sprite:
		sprite.animation_finished.connect(_on_anim_finished)
	add_to_group("actors")

func _physics_process(delta: float) -> void:
	if GameManager.is_frozen():
		return
	_update_timers(delta)
	_update_vertical(delta)
	_update_movement(delta)
	_update_visual(delta)

func _update_timers(delta: float) -> void:
	if hitstun_frames > 0:
		hitstun_frames -= 1
		if hitstun_frames <= 0 and state == State.HURT:
			set_state(State.IDLE)
	if invuln_frames > 0:
		invuln_frames -= 1
	if flash_time > 0.0:
		flash_time -= delta
		if flash_time <= 0.0 and sprite:
			sprite.material = null
			sprite.modulate = Color.WHITE

func _update_vertical(delta: float) -> void:
	if z_height > 0.0 or z_velocity != 0.0:
		z_velocity -= GRAVITY * delta
		z_height += z_velocity * delta
		if z_height <= 0.0:
			z_height = 0.0
			var was_falling := z_velocity < -40.0
			z_velocity = 0.0
			_on_landed(was_falling)

func _on_landed(hard: bool) -> void:
	pass

func _update_movement(delta: float) -> void:
	var vel := Vector2.ZERO
	if can_move():
		var speed := get_current_speed()
		vel = Vector2(move_input.x * speed, move_input.y * speed * lane_speed_ratio)
	vel += knockback_velocity
	velocity = vel
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 620.0 * delta)
	_clamp_bounds()

func _clamp_bounds() -> void:
	position.x = clampf(position.x, bounds_min, bounds_max)
	if lane_max > lane_min:
		position.y = clampf(position.y, lane_min, lane_max)

func get_current_speed() -> float:
	return move_speed

func can_move() -> bool:
	# DODGE is included: a roll is committed movement, driven by roll_dir rather than input.
	return state in [State.IDLE, State.WALK, State.RUN, State.JUMP, State.DODGE] and not dead

## True while holding a guard. Overridden by Player; enemies do not guard yet.
func is_guarding() -> bool:
	return false

func can_act() -> bool:
	return state in [State.IDLE, State.WALK, State.RUN] and not dead

func set_state(new_state: State) -> void:
	if state == new_state or dead:
		return
	state = new_state
	state_changed.emit(new_state)

func _update_visual(_delta: float) -> void:
	if visual:
		visual.position.y = -z_height
	if sprite:
		sprite.flip_h = facing < 0
	if shadow:
		shadow.visible = not dead or state == State.KNOCKDOWN
		var s := clampf(1.0 - z_height / 220.0, 0.45, 1.0)
		shadow.scale = Vector2(s, s)
		shadow.modulate.a = clampf(0.55 * s, 0.15, 0.55)
	z_index = 0

# ---------------- Animation ----------------
func play_anim(name: String, lock: bool = false, force: bool = false) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(name):
		return
	if _anim_lock and not force and name == _current_anim:
		return
	if _current_anim == name and sprite.is_playing() and not force:
		return
	_current_anim = name
	_anim_lock = lock
	sprite.play(name)

func _on_anim_finished() -> void:
	_anim_lock = false

func anim_done() -> bool:
	return not _anim_lock

# ---------------- Damage ----------------
func take_damage(d: DamageData) -> bool:
	if dead or invuln_frames > 0:
		return false
	if is_guarding() and _guard_absorbs(d):
		on_guarded(d)
		return true
	var amount := compute_damage(d)
	hp = maxi(0, hp - amount)
	_spawn_hit_fx(d, amount)
	on_damaged(d, amount)
	if hp <= 0:
		die(d)
		return true
	# Armor: heavy enemies shrug off weak hits
	if armor_threshold > 0 and amount < armor_threshold and not d.knockdown:
		return true
	apply_hit_reaction(d)
	return true

## A guard holds against ordinary attacks. Heavy and armored blows break through it.
func _guard_absorbs(d: DamageData) -> bool:
	return not (d.heavy or d.knockdown)

func on_guarded(d: DamageData) -> void:
	pass

func compute_damage(d: DamageData) -> int:
	return maxi(1, d.amount)

func on_damaged(d: DamageData, amount: int) -> void:
	pass

func apply_hit_reaction(d: DamageData) -> void:
	release_grab()
	if grabbed_by and is_instance_valid(grabbed_by) and grabbed_by.has_method("release_grab"):
		grabbed_by.release_grab()
	hitstun_frames = d.hitstun
	knockback_velocity = Vector2(d.knockback.x * d.direction / maxf(weight, 0.25), d.knockback.y / maxf(weight, 0.25))
	if d.launch > 0.0 or d.knockdown:
		z_velocity = maxf(d.launch, 150.0) / maxf(weight, 0.4)
		set_state(State.KNOCKDOWN)
		play_anim("fall", true, true)
		AudioManager.play_sfx("knockdown", -3.0)
	else:
		set_state(State.HURT)
		play_anim("hurt", true, true)
	flash(0.12)

func flash(duration: float = 0.12) -> void:
	if sprite == null:
		return
	flash_time = duration
	sprite.modulate = Color(2.4, 2.2, 2.2, 1.0)

func _spawn_hit_fx(d: DamageData, amount: int) -> void:
	var fx_pos := global_position + Vector2(d.direction * 8.0, -z_height - 22.0)
	FX.spawn(d.hit_fx, fx_pos, get_parent())
	if d.hit_sound != "":
		AudioManager.play_sfx(d.hit_sound)

func die(d: DamageData = null) -> void:
	if dead:
		return
	dead = true
	hp = 0
	release_grab()
	set_state(State.DEFEATED)
	play_anim("fall", true, true)
	if d:
		knockback_velocity = Vector2(d.knockback.x * d.direction * 1.2, 0)
		z_velocity = 180.0
	defeated.emit(self)

# ---------------- Grab ----------------
func try_grab(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not target.can_be_grabbed or target.dead:
		return false
	if target.has_method("on_grabbed") and target.on_grabbed(self):
		grabbing = target
		set_state(State.GRABBING)
		return true
	return false

func on_grabbed(by: Node) -> bool:
	if not can_be_grabbed or dead:
		return false
	grabbed_by = by
	set_state(State.GRABBED)
	play_anim("grabbed", true, true)
	hitstun_frames = 0
	return true

func release_grab() -> void:
	if grabbing and is_instance_valid(grabbing):
		grabbing.grabbed_by = null
		if grabbing.state == State.GRABBED:
			grabbing.set_state(State.IDLE)
	grabbing = null
	if state == State.GRABBING:
		set_state(State.IDLE)

## Called when this actor is thrown by someone else. Thrown bodies damage what they hit.
func set_thrown(by: Node) -> void:
	pass

func face_towards(x: float) -> void:
	if absf(x - global_position.x) > 1.0:
		facing = 1 if x > global_position.x else -1

func lane_distance_to(other: Node2D) -> float:
	return absf(other.global_position.y - global_position.y)

func set_lane_bounds(min_y: float, max_y: float, min_x: float, max_x: float) -> void:
	lane_min = min_y
	lane_max = max_y
	bounds_min = min_x
	bounds_max = max_x

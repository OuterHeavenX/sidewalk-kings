class_name WeaponBase
extends Node2D
## Environmental weapon: lies on the ground, gets picked up, swung, thrown, and breaks.
## New weapons are new WeaponData resources, not new scripts.

@export var weapon_id: String = "bat"

var data: WeaponData = null
var held_by: Node = null
var thrown: bool = false
var uses_left: int = 6
var _velocity: Vector2 = Vector2.ZERO
var _z: float = 0.0
var _zv: float = 0.0
var _spin: float = 0.0
var _thrower: Node = null
var _throw_damage: DamageData = null
var _hit_ids: Array[int] = []

@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow

func _ready() -> void:
	add_to_group("weapons")
	_load_data()
	set_physics_process(true)

func _load_data() -> void:
	data = ContentDB.get_weapon(weapon_id)
	if data == null:
		push_warning("[Weapon] unknown id %s" % weapon_id)
		queue_free()
		return
	uses_left = data.durability
	if sprite and data.texture:
		sprite.texture = data.texture

func _physics_process(delta: float) -> void:
	if GameManager.is_frozen():
		return
	if held_by != null:
		return
	if thrown:
		_update_thrown(delta)
	elif _z > 0.0 or _zv != 0.0:
		_update_falling(delta)

func _update_falling(delta: float) -> void:
	_zv -= Actor.GRAVITY * delta
	_z += _zv * delta
	position += _velocity * delta
	_velocity = _velocity.move_toward(Vector2.ZERO, 300.0 * delta)
	if _z <= 0.0:
		_z = 0.0
		_zv = 0.0
		_velocity = Vector2.ZERO
		sprite.rotation = 0.0
	_apply_visual()

func _update_thrown(delta: float) -> void:
	position += _velocity * delta
	_zv -= Actor.GRAVITY * 0.42 * delta
	_z += _zv * delta
	_spin += delta * 22.0 * signf(_velocity.x)
	sprite.rotation = _spin
	_apply_visual()
	_check_throw_hits()
	if _z <= 0.0:
		_land_thrown()

func _apply_visual() -> void:
	if sprite:
		sprite.position.y = -_z - 4.0
	if shadow:
		shadow.visible = true
		var s := clampf(1.0 - _z / 160.0, 0.4, 1.0)
		shadow.scale = Vector2(s * 0.7, s * 0.7)
		shadow.modulate.a = 0.4 * s

func _check_throw_hits() -> void:
	if _throw_damage == null:
		return
	for group in ["enemies", "player", "props"]:
		for n in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(n) or n == _thrower:
				continue
			if group == "player" and _thrower != null and _thrower.is_in_group("player"):
				continue
			if group == "enemies" and _thrower != null and _thrower.is_in_group("enemies"):
				continue
			if n.get("dead") == true:
				continue
			var d := global_position.distance_to(n.global_position)
			var nz: float = n.z_height if n.get("z_height") != null else 0.0
			if d < 16.0 and absf(nz - _z) < 30.0:
				var id := n.get_instance_id()
				if id in _hit_ids:
					continue
				_hit_ids.append(id)
				if n.has_method("take_damage"):
					_throw_damage.direction = signi(int(signf(_velocity.x)))
					n.take_damage(_throw_damage)
				EventBus.screen_shake.emit(2.0, 0.12)
				_land_thrown()
				return

func _land_thrown() -> void:
	thrown = false
	_z = 0.0
	_zv = 0.0
	_velocity = Vector2.ZERO
	sprite.rotation = 0.0
	_apply_visual()
	AudioManager.play_sfx("break_object" if data.breaks else "land", -10.0)
	if data.style == WeaponData.Style.BOUNCE or data.bounces_on_throw:
		return
	if data.breaks:
		uses_left -= 1
		if uses_left <= 0:
			break_weapon()

# ---------------- Handling ----------------
func pick_up(actor: Node) -> void:
	held_by = actor
	thrown = false
	_z = 0.0
	_zv = 0.0
	_velocity = Vector2.ZERO
	if sprite:
		sprite.position = data.hand_offset
		sprite.rotation_degrees = data.rotation_degrees_held
	if shadow:
		shadow.visible = false

func drop() -> void:
	if held_by == null:
		return
	global_position = held_by.global_position + Vector2(held_by.facing * 8.0, 2.0)
	held_by = null
	if sprite:
		sprite.position = Vector2.ZERO
		sprite.rotation_degrees = 0.0
	_z = 12.0
	_zv = 40.0
	_velocity = Vector2(randf_range(-20, 20), 0)
	if shadow:
		shadow.visible = true

## Spawn on the ground with a small pop, used when a prop breaks open.
func drop_from(from: Vector2) -> void:
	global_position = from
	held_by = null
	thrown = false
	_z = 14.0
	_zv = 70.0
	_velocity = Vector2(randf_range(-35, 35), 0)
	if shadow:
		shadow.visible = true

func throw_forward(actor: Node, facing: int) -> void:
	held_by = null
	thrown = true
	_hit_ids.clear()
	_thrower = actor
	global_position = actor.global_position + Vector2(facing * 10.0, 0)
	_z = 26.0 + (actor.z_height if actor.get("z_height") != null else 0.0)
	_zv = 40.0
	_velocity = Vector2(data.throw_speed * facing, 0)
	if sprite:
		sprite.position = Vector2.ZERO
	var m: MoveData = ContentDB.get_move("weapon_throw")
	var dmg := DamageData.new()
	dmg.source = actor
	dmg.amount = data.throw_damage
	dmg.direction = facing
	dmg.knockback = Vector2(data.knockback.x * 1.3, 0)
	dmg.hitstun = 20
	dmg.knockdown = true
	dmg.heavy = true
	dmg.kind = MoveData.DamageKind.WEAPON
	dmg.hit_sound = data.hit_sound
	dmg.hit_fx = "spark_weapon"
	dmg.hit_pause = 0.06
	dmg.screen_shake = 2.5
	dmg.from_weapon = true
	if m:
		dmg.hitstun = m.hitstun
	if actor.is_in_group("player"):
		dmg.amount = int(dmg.amount * GameManager.player_data.get_weapon_multiplier())
	_throw_damage = dmg

## Called by the wielder each time a swing connects. Returns true if the weapon survived.
func register_swing_hit() -> bool:
	if not data.breaks:
		return true
	uses_left -= 1
	if uses_left <= 0:
		break_weapon()
		return false
	if uses_left == 1 and sprite:
		sprite.modulate = Color(1.0, 0.75, 0.7)
	return true

func break_weapon() -> void:
	AudioManager.play_sfx("weapon_break", -4.0)
	FX.spawn("spark_weapon", global_position + Vector2(0, -20), get_parent())
	if is_instance_valid(held_by) and held_by.get("held_weapon") == self:
		held_by.held_weapon = null
		if held_by.is_in_group("player"):
			GameManager.player_data.equipped_weapon = ""
			GameManager.notify("%s broke!" % data.display_name, "warn")
	queue_free()

func get_swing_damage(wielder: Node) -> int:
	var base := data.damage
	if wielder != null and wielder.is_in_group("player"):
		base = int(base * GameManager.player_data.get_weapon_multiplier())
	return base

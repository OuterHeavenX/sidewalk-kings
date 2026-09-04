class_name Hurtbox
extends Area2D
## Receives DamageData. Attached to any actor that can be hit.
## Owner must implement take_damage(DamageData).

signal hurt(damage: DamageData)

@export var actor_path: NodePath
var actor: Node = null
var active: bool = true
var invulnerable_until_ms: int = 0

func _ready() -> void:
	actor = get_node_or_null(actor_path) if actor_path != NodePath() else get_parent()
	monitorable = true
	monitoring = false

func is_invulnerable() -> bool:
	return Time.get_ticks_msec() < invulnerable_until_ms

func set_invulnerable(seconds: float) -> void:
	invulnerable_until_ms = maxi(invulnerable_until_ms, Time.get_ticks_msec() + int(seconds * 1000.0))

## Called by Hitbox. Returns true if the hit registered.
func apply(damage: DamageData) -> bool:
	if not active or is_invulnerable() or actor == null:
		return false
	if not actor.has_method("take_damage"):
		return false
	hurt.emit(damage)
	return actor.take_damage(damage)

func get_z_height() -> float:
	if actor and actor.get("z_height") != null:
		return float(actor.z_height)
	return 0.0

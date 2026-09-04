class_name Pickup
extends Node2D
## Base for anything that bounces onto the street and is collected by walking over it.

@export var auto_collect_radius: float = 13.0
@export var magnet_radius: float = 34.0

var velocity: Vector2 = Vector2.ZERO
var z: float = 0.0
var zv: float = 0.0
var bounces: int = 0
var collected: bool = false
var life: float = 45.0
var settle_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow

func _ready() -> void:
	add_to_group("pickups")

func launch(from: Vector2, vel: Vector2, up: float) -> void:
	global_position = from
	velocity = vel
	zv = up
	z = 6.0

func _physics_process(delta: float) -> void:
	if GameManager.is_frozen() or collected:
		return
	life -= delta
	if life <= 0.0:
		_fade_out()
		return
	if z > 0.0 or zv != 0.0:
		zv -= Actor.GRAVITY * delta
		z += zv * delta
		position += velocity * delta
		velocity = velocity.move_toward(Vector2.ZERO, 240.0 * delta)
		if z <= 0.0:
			z = 0.0
			if bounces < 2 and absf(zv) > 45.0:
				bounces += 1
				zv = -zv * 0.42
				velocity *= 0.5
				_on_bounce()
			else:
				zv = 0.0
				velocity = Vector2.ZERO
	else:
		settle_time += delta
	_update_visual(delta)
	_check_player(delta)

func _on_bounce() -> void:
	AudioManager.play_sfx("money", -18.0, 0.12, 60)

func _update_visual(delta: float) -> void:
	if sprite:
		sprite.position.y = -z - 4.0
		sprite.position.x = 0.0
		if z <= 0.0:
			sprite.position.y = -4.0 + sin(Time.get_ticks_msec() * 0.005) * 1.2
	if shadow:
		var s := clampf(1.0 - z / 90.0, 0.4, 1.0)
		shadow.scale = Vector2(s * 0.6, s * 0.6)
		shadow.modulate.a = 0.4 * s
	if life < 5.0:
		visible = int(life * 8.0) % 2 == 0

func _check_player(delta: float) -> void:
	var p := GameManager.player
	if not is_instance_valid(p) or p.dead:
		return
	var target_pos: Vector2 = p.global_position
	var d := global_position.distance_to(target_pos)
	if d < magnet_radius and settle_time > 0.12:
		var pull: Vector2 = (target_pos - global_position).normalized() * (magnet_radius - d) * 7.0
		position += pull * delta
	if d < auto_collect_radius and absf(float(p.z_height) - z) < 40.0:
		collect(p)

func collect(_by: Node) -> void:
	collected = true
	queue_free()

func _fade_out() -> void:
	collected = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)

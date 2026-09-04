class_name Projectile
extends Node2D
## Thrown object used by ranged enemies (bottles, bricks, cans).

var velocity: Vector2 = Vector2.ZERO
var z: float = 26.0
var zv: float = 90.0
var damage: DamageData = null
var source: Node = null
var life: float = 3.0

@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow

func launch(from: Node, dir: Vector2, move: MoveData, multiplier: float = 1.0) -> void:
	source = from
	global_position = from.global_position + Vector2(dir.x * 10.0, 0)
	z = 28.0 + (from.z_height if from.get("z_height") != null else 0.0)
	zv = 70.0
	velocity = Vector2(dir.x * 190.0, 0)
	damage = DamageData.from_move(move, from, signi(int(signf(dir.x))), multiplier)
	damage.knockdown = false

func _ready() -> void:
	add_to_group("projectiles")

func _physics_process(delta: float) -> void:
	if GameManager.is_frozen():
		return
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	position += velocity * delta
	zv -= Actor.GRAVITY * 0.5 * delta
	z += zv * delta
	if sprite:
		sprite.position.y = -z
		sprite.rotation += delta * 9.0
	if shadow:
		var s := clampf(1.0 - z / 150.0, 0.4, 1.0)
		shadow.scale = Vector2(s * 0.6, s * 0.6)
		shadow.modulate.a = 0.35 * s
	var p := GameManager.player
	if is_instance_valid(p) and not p.dead:
		if global_position.distance_to(p.global_position) < 15.0 and absf(p.z_height - z) < 28.0:
			p.take_damage(damage)
			_burst()
			return
	if z <= 0.0:
		_burst()

func _burst() -> void:
	FX.spawn("spark_small", global_position + Vector2(0, -maxf(z, 4.0)), get_parent())
	AudioManager.play_sfx("break_object", -12.0)
	queue_free()

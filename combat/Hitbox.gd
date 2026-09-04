class_name Hitbox
extends Area2D
## Deals DamageData to Hurtboxes it overlaps while active.
##
## The world is a shallow 2.5D lane: x = along the street, y = depth into the lane,
## and z_height = how far off the ground a fighter is. The Area2D shape covers x/y;
## the z difference is checked separately so jumping actually dodges low attacks.

signal hit_target(target: Node, damage: DamageData)

## Roughly how tall a fighter stands, in pixels. Used to test whether a strike lands
## somewhere on the target's body rather than exactly at its feet.
const BODY_HEIGHT := 44.0

var damage: DamageData = null
var owner_actor: Node = null
var active: bool = false
var z_center: float = 0.0
var z_tolerance: float = 30.0
var already_hit: Array[int] = []
var max_targets: int = 8

var _shape: CollisionShape2D

func _ready() -> void:
	# Monitoring stays on: enabling it per swing costs a physics frame, which is long
	# enough for a 3-frame jab to miss entirely. `active` gates the actual hit test.
	monitoring = true
	monitorable = false
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	add_child(_shape)
	set_physics_process(false)

func configure(move: MoveData, facing: int, dmg: DamageData, actor: Node) -> void:
	owner_actor = actor
	damage = dmg
	var rect: RectangleShape2D = _shape.shape
	rect.size = Vector2(maxf(4.0, move.hitbox_size.x), maxf(4.0, move.lane_tolerance * 2.0))
	position = Vector2(move.hitbox_offset.x * facing, 0.0)
	# hitbox_offset.y is screen-space (negative is up), so a strike 22px above the
	# attacker's feet is stored as -22.
	z_center = -move.hitbox_offset.y
	# Slack beyond the target's body, which is what makes jumping over an attack work.
	z_tolerance = maxf(8.0, move.hitbox_size.y * 0.5)

func activate() -> void:
	already_hit.clear()
	active = true
	set_physics_process(true)

func deactivate() -> void:
	active = false
	set_physics_process(false)

func _physics_process(_delta: float) -> void:
	if not active or damage == null:
		return
	for area in get_overlapping_areas():
		if not (area is Hurtbox):
			continue
		var hb: Hurtbox = area
		if hb.actor == owner_actor or hb.actor == null:
			continue
		var id := hb.actor.get_instance_id()
		if id in already_hit:
			continue
		# Where the strike lands, in world height.
		var my_z: float = z_center + (owner_actor.z_height if owner_actor and owner_actor.get("z_height") != null else 0.0)
		# The target occupies a span, not a point: a jump kick aimed below the attacker
		# should still catch someone standing on the ground.
		var target_feet: float = hb.get_z_height()
		var target_head: float = target_feet + BODY_HEIGHT
		if my_z < target_feet - z_tolerance or my_z > target_head + z_tolerance:
			continue
		already_hit.append(id)
		if hb.apply(damage):
			hit_target.emit(hb.actor, damage)
		if already_hit.size() >= max_targets:
			break

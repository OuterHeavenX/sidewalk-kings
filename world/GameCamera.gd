class_name GameCamera
extends Camera2D
## Smooth side-scrolling camera with a dead zone, look-ahead in the facing direction,
## clamped to the area bounds, plus trauma-based shake.

@export var dead_zone_x: float = 26.0
@export var dead_zone_y: float = 14.0
@export var look_ahead: float = 30.0
@export var follow_speed: float = 6.0
@export var vertical_factor: float = 0.35

var target: Node2D = null
var locked: bool = false
var lock_center: float = 0.0
var lock_half_width: float = 160.0
var trauma: float = 0.0
var shake_scale: float = 1.0

var _desired: Vector2 = Vector2.ZERO
var _look: float = 0.0
var _base_y: float = 0.0

func _ready() -> void:
	EventBus.screen_shake.connect(_on_shake)
	make_current()

func setup(t: Node2D, min_x: float, max_x: float, base_y: float) -> void:
	target = t
	limit_left = int(min_x)
	limit_right = int(max_x)
	_base_y = base_y
	position_smoothing_enabled = false
	if is_instance_valid(t):
		global_position = Vector2(t.global_position.x, base_y)
		_desired = global_position

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var tp := target.global_position
	# Look-ahead follows facing, easing so a turn doesn't snap the view.
	var face: float = float(target.facing) if target.get("facing") != null else 1.0
	_look = lerpf(_look, face * look_ahead, delta * 2.4)

	var goal_x := tp.x + _look
	if absf(goal_x - _desired.x) > dead_zone_x:
		_desired.x = goal_x - signf(goal_x - _desired.x) * dead_zone_x
	var goal_y := _base_y + (tp.y - _base_y) * vertical_factor
	if absf(goal_y - _desired.y) > dead_zone_y:
		_desired.y = goal_y - signf(goal_y - _desired.y) * dead_zone_y

	if locked:
		_desired.x = clampf(_desired.x, lock_center - lock_half_width, lock_center + lock_half_width)

	global_position = global_position.lerp(_desired, clampf(delta * follow_speed, 0.0, 1.0))

	if trauma > 0.0:
		trauma = maxf(0.0, trauma - delta * 3.4)
		var amount := trauma * trauma * shake_scale
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amount * 5.0
	elif offset != Vector2.ZERO:
		offset = offset.lerp(Vector2.ZERO, 0.4)

func _on_shake(strength: float, _duration: float) -> void:
	trauma = clampf(trauma + strength * 0.14, 0.0, 1.0)

## Lock the camera during an encounter so the arena has clear edges.
func lock_to(center_x: float, half_width: float) -> void:
	locked = true
	lock_center = center_x
	lock_half_width = half_width

func unlock() -> void:
	locked = false

func snap_to_target() -> void:
	if is_instance_valid(target):
		_desired = Vector2(target.global_position.x, _base_y)
		global_position = _desired
		offset = Vector2.ZERO

class_name TouchControls
extends Control
## Multitouch on-screen controls. Every button and the stick track their OWN touch index,
## so several inputs work at once. Static fields let Player read the stick without a lookup.

static var active: bool = false
static var move_vector: Vector2 = Vector2.ZERO
static var sprinting: bool = false

const DEADZONE := 0.18
const STICK_RADIUS := 46.0
const BTN := 66.0

@onready var stick_base: TextureRect = $Stick/Base
@onready var stick_knob: TextureRect = $Stick/Knob
@onready var buttons_root: Control = $Buttons

var _stick_touch: int = -1
var _stick_origin: Vector2 = Vector2.ZERO
var _button_touch: Dictionary = {}      # touch index -> action name
var _buttons: Array[Dictionary] = []    # {name, action, node}
var _safe: Rect2 = Rect2()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_collect_buttons()
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	EventBus.game_state_changed.connect(_on_state_changed)
	EventBus.touch_mode_changed.connect(_on_touch_mode)
	visible = InputManager.is_touch()
	active = visible
	set_process_input(true)

func _exit_tree() -> void:
	active = false
	move_vector = Vector2.ZERO
	sprinting = false

func _collect_buttons() -> void:
	_buttons.clear()
	for child in buttons_root.get_children():
		if child is TextureRect and child.has_meta("action"):
			_buttons.append({"action": str(child.get_meta("action")), "node": child})

func _on_touch_mode(enabled: bool) -> void:
	visible = enabled
	active = enabled
	if not enabled:
		_reset()

func _on_state_changed(new_state: int) -> void:
	var playing := new_state == GameManager.State.PLAYING
	if visible != (playing and InputManager.is_touch()):
		visible = playing and InputManager.is_touch()
		active = visible
		if not visible:
			_reset()

func _reset() -> void:
	_stick_touch = -1
	_button_touch.clear()
	move_vector = Vector2.ZERO
	sprinting = false
	if stick_knob:
		stick_knob.position = _knob_home()
	for b in _buttons:
		b.node.modulate = Color(1, 1, 1, 0.78)

func _knob_home() -> Vector2:
	return stick_base.position + stick_base.size * 0.5 - stick_knob.size * 0.5

func _apply_safe_area() -> void:
	var vp := get_viewport_rect().size
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	var pad_l := 10.0
	var pad_r := 10.0
	var pad_b := 10.0
	if win.x > 0 and win.y > 0 and safe.size.x > 0:
		pad_l += float(safe.position.x) / float(win.x) * vp.x
		pad_r += float(win.x - (safe.position.x + safe.size.x)) / float(win.x) * vp.x
		pad_b += float(win.y - (safe.position.y + safe.size.y)) / float(win.y) * vp.y
	# Stick, lower-left
	var sb_size := Vector2(STICK_RADIUS * 2.0, STICK_RADIUS * 2.0)
	stick_base.size = sb_size
	stick_base.position = Vector2(pad_l + 6.0, vp.y - pad_b - sb_size.y - 6.0)
	stick_knob.size = Vector2(STICK_RADIUS, STICK_RADIUS)
	stick_knob.position = _knob_home()
	# Buttons, lower-right in a fan
	var layout := {
		"attack_light": Vector2(-1.72, -0.30),
		"attack_heavy": Vector2(-0.95, -0.92),
		"jump": Vector2(-0.30, -0.20),
		"grab": Vector2(-1.05, 0.30),
		"special": Vector2(-0.28, -1.10),
	}
	for b in _buttons:
		var act: String = b.action
		var node: TextureRect = b.node
		node.size = Vector2(BTN, BTN)
		if act == "pause":
			node.position = Vector2(vp.x - pad_r - 34.0, 8.0)
			node.size = Vector2(30, 30)
			continue
		var off: Vector2 = layout.get(act, Vector2(-1, 0))
		node.position = Vector2(vp.x - pad_r + off.x * BTN, vp.y - pad_b - BTN + off.y * BTN)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_touch_move(event.index, event.position)

func _screen_to_ui(p: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0 or win.y <= 0:
		return p
	# The viewport is stretched; map window pixels into UI space.
	return get_viewport().get_screen_transform().affine_inverse() * p

func _touch_down(index: int, pos: Vector2) -> void:
	if not visible:
		return
	var p := _screen_to_ui(pos)
	for b in _buttons:
		var node: TextureRect = b.node
		var r := Rect2(node.position, node.size).grow(6.0)
		if r.has_point(p):
			_button_touch[index] = b.action
			node.modulate = Color(1.35, 1.35, 1.35, 1.0)
			_press(b.action, true)
			return
	# Anything on the left half becomes the stick
	if p.x < get_viewport_rect().size.x * 0.5 and _stick_touch == -1:
		_stick_touch = index
		_stick_origin = p
		_update_stick(p)

func _touch_move(index: int, pos: Vector2) -> void:
	if index == _stick_touch:
		_update_stick(_screen_to_ui(pos))

func _touch_up(index: int) -> void:
	if index == _stick_touch:
		_stick_touch = -1
		move_vector = Vector2.ZERO
		sprinting = false
		stick_knob.position = _knob_home()
	if _button_touch.has(index):
		var act: String = _button_touch[index]
		_button_touch.erase(index)
		for b in _buttons:
			if b.action == act:
				b.node.modulate = Color(1, 1, 1, 0.78)
		_press(act, false)

func _update_stick(p: Vector2) -> void:
	var delta := p - _stick_origin
	var r := STICK_RADIUS
	var mag := delta.length()
	if mag > r:
		# Move the origin so the stick follows a long drag instead of sticking at the rim.
		_stick_origin = p - delta.normalized() * r
		delta = delta.normalized() * r
		mag = r
	var v := delta / r
	move_vector = v if v.length() > DEADZONE else Vector2.ZERO
	sprinting = v.length() > 0.82
	stick_base.position = _stick_origin - stick_base.size * 0.5
	stick_knob.position = _stick_origin + delta - stick_knob.size * 0.5

func _press(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)

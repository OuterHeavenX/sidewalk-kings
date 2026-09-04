class_name TouchControls
extends Control
## Multitouch on-screen controls. Every button and the stick track their OWN touch index,
## so several inputs work at once. Static fields let Player read the stick without a lookup.

static var active: bool = false
static var move_vector: Vector2 = Vector2.ZERO
static var sprinting: bool = false

const DEADZONE := 0.18
const STICK_RADIUS := 46.0
const BTN := 40.0

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
	visible = false
	active = false
	set_process_input(true)
	# Defer so the viewport has its final size before buttons are placed.
	call_deferred("_set_shown", InputManager.is_touch() and _gameplay_state())

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
	_set_shown(enabled and _gameplay_state())

func _on_state_changed(_new_state: int) -> void:
	_set_shown(InputManager.is_touch() and _gameplay_state())

func _gameplay_state() -> bool:
	return GameManager.state in [GameManager.State.PLAYING, GameManager.State.DIALOGUE]

func _set_shown(shown: bool) -> void:
	if visible == shown:
		return
	visible = shown
	active = shown
	if shown:
		_apply_safe_area()
	else:
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

## Insets for notches and rounded corners, in UI units.
## DisplayServer.get_display_safe_area() is reported in screen coordinates and on desktop
## describes the whole monitor, so it is only trusted when it actually sits inside the
## window and the platform is one that has cutouts.
func _safe_insets(vp: Vector2) -> Vector3:
	var base := Vector3(10.0, 10.0, 10.0)      # left, right, bottom
	if not (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")):
		return base
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return base
	if safe.size.x > win.x or safe.size.y > win.y:
		return base                             # not describing this window
	var sx := vp.x / float(win.x)
	var sy := vp.y / float(win.y)
	var max_x := vp.x * 0.2
	var max_y := vp.y * 0.2
	base.x += clampf(float(safe.position.x) * sx, 0.0, max_x)
	base.y += clampf(float(win.x - (safe.position.x + safe.size.x)) * sx, 0.0, max_x)
	base.z += clampf(float(win.y - (safe.position.y + safe.size.y)) * sy, 0.0, max_y)
	return base

func _apply_safe_area() -> void:
	var vp := get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	var insets := _safe_insets(vp)
	var pad_l := insets.x
	var pad_r := insets.y
	var pad_b := insets.z
	# Scale the whole layout down on very short viewports so nothing overlaps.
	var ui_scale := clampf(vp.y / 270.0, 0.75, 1.35)
	var btn := BTN * ui_scale
	var stick_r := STICK_RADIUS * ui_scale
	# Stick, lower-left
	var sb_size := Vector2(stick_r * 2.0, stick_r * 2.0)
	stick_base.size = sb_size
	stick_base.position = Vector2(pad_l + 6.0, vp.y - pad_b - sb_size.y - 6.0)
	stick_knob.size = Vector2(stick_r, stick_r)
	stick_knob.position = _knob_home()
	# Action buttons sit on an arc around the bottom-right corner, thumb-reachable and
	# always fully inside the viewport.
	var centre := Vector2(vp.x - pad_r - btn * 1.9, vp.y - pad_b - btn * 1.35)
	var radius := btn * 1.05
	var angles := {
		"jump": -10.0,
		"attack_light": -70.0,
		"attack_heavy": -130.0,
		"special": -180.0,
		"grab": 60.0,
	}
	for b in _buttons:
		var act: String = b.action
		var node: TextureRect = b.node
		if act == "pause":
			node.size = Vector2(26, 26)
			node.position = Vector2(vp.x - pad_r - 30.0, 8.0)
			continue
		node.size = Vector2(btn, btn)
		var ang: float = deg_to_rad(float(angles.get(act, -90.0)))
		var pos := centre + Vector2(cos(ang), sin(ang)) * radius - Vector2(btn, btn) * 0.5
		# Never let a button leave the screen on an unusual aspect ratio.
		pos.x = clampf(pos.x, 4.0, vp.x - btn - 4.0)
		pos.y = clampf(pos.y, 4.0, vp.y - btn - 4.0)
		node.position = pos

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
	var r := maxf(12.0, stick_base.size.x * 0.5)
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

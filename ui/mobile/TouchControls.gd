class_name TouchControls
extends Control
## Multitouch on-screen controls. Every button and the stick track their OWN touch index,
## so several inputs work at once. Static fields let Player read the stick without a lookup.

static var active: bool = false
static var move_vector: Vector2 = Vector2.ZERO
static var sprinting: bool = false
static var guarding: bool = false

const DEADZONE := 0.18
const STICK_RADIUS := 50.0
const BTN := 44.0
## Resting transparency for the on-screen buttons; they sit on top of the game.
const IDLE_ALPHA := 0.62

@onready var stick_base: TextureRect = $Stick/Base
@onready var stick_knob: TextureRect = $Stick/Knob
@onready var buttons_root: Control = $Buttons

var _stick_touch: int = -1
var _stick_origin: Vector2 = Vector2.ZERO
var _button_touch: Dictionary = {}      # touch index -> action name
var _buttons: Array[Dictionary] = []    # {name, action, node}
var _stick_home: Vector2 = Vector2.ZERO

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
	guarding = false

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
	guarding = false
	if stick_base and stick_knob:
		_recentre_stick()
	for b in _buttons:
		b.node.modulate = Color(1, 1, 1, IDLE_ALPHA)

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
	stick_base.custom_minimum_size = sb_size
	stick_base.size = sb_size
	_stick_home = Vector2(pad_l + 6.0, vp.y - pad_b - sb_size.y - 6.0)
	stick_base.position = _stick_home
	stick_knob.custom_minimum_size = Vector2(stick_r, stick_r)
	stick_knob.size = Vector2(stick_r, stick_r)
	stick_knob.position = _knob_home()
	# Action buttons form a compact diamond in the bottom-right corner, the way a gamepad
	# lays out its face buttons. A wide arc pushed the top button almost half way up the
	# screen, which is neither reachable nor readable over the game.
	var centre := Vector2(vp.x - pad_r - btn * 2.2, vp.y - pad_b - btn * 2.2)
	# Spacing >= one button width, so no two hit rectangles touch even diagonally.
	var d := btn * 1.08
	var offsets := {
		"attack_light": Vector2(1.0, 0.0),     # nearest the thumb: the button used most
		"attack_heavy": Vector2(0.0, -1.0),
		"jump": Vector2(-1.0, 0.0),
		"grab": Vector2(0.0, 1.0),
		# Special and guard flank the diamond on the left, where the thumb sweeps in.
		"special": Vector2(-2.05, -0.65),
		"guard": Vector2(-2.05, 0.65),
	}
	for b in _buttons:
		var act: String = b.action
		var node: TextureRect = b.node
		if act == "pause":
			node.custom_minimum_size = Vector2(26, 26)
			node.size = Vector2(26, 26)
			# Top centre: clear of the vitals on the left and the money on the right.
			node.position = Vector2(vp.x * 0.5 - 13.0, 6.0)
			continue
		node.custom_minimum_size = Vector2(btn, btn)
		node.size = Vector2(btn, btn)
		var off: Vector2 = offsets.get(act, Vector2(1.0, 0.0))
		var pos := centre + off * d - Vector2(btn, btn) * 0.5
		# Never let a button leave the screen on an unusual aspect ratio.
		pos.x = clampf(pos.x, 4.0, vp.x - btn - 4.0)
		pos.y = clampf(pos.y, 4.0, vp.y - btn - 4.0)
		node.position = pos

## Touch positions arrive from the input system already expressed in this viewport's
## 2D coordinate space, which is the same space Control positions live in. They must NOT
## be run through the screen transform again: on a phone that shrinks every tap toward the
## top-left by the content scale factor, so nothing can ever be hit.
##
## Events are only consumed when a control actually takes them, so a tap on empty screen
## still reaches the dialogue box to advance a conversation.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var used := _touch_down(event.index, event.position) if event.pressed else _touch_up(event.index)
		if used:
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _stick_touch:
			_update_stick(event.position)
			get_viewport().set_input_as_handled()

func _touch_down(index: int, p: Vector2) -> bool:
	for b in _buttons:
		var node: TextureRect = b.node
		# get_global_rect() accounts for the parent Control offsets, so this stays correct
		# no matter how the layout is nested.
		if node.get_global_rect().grow(8.0).has_point(p):
			_button_touch[index] = b.action
			node.modulate = Color(1.35, 1.35, 1.35, 1.0)
			if b.action == "guard":
				guarding = true
			_press(b.action, true)
			return true
	# Anything on the left half drives the stick, so the thumb never has to find a target.
	if p.x < get_viewport_rect().size.x * 0.5 and _stick_touch == -1:
		_stick_touch = index
		_stick_origin = p
		_update_stick(p)
		return true
	return false

func _touch_up(index: int) -> bool:
	var used := false
	if index == _stick_touch:
		_stick_touch = -1
		move_vector = Vector2.ZERO
		sprinting = false
		# Put the stick back where it lives. Without this it stays wherever it was last
		# dragged and reads as a broken control.
		_recentre_stick()
		used = true
	if _button_touch.has(index):
		var act: String = _button_touch[index]
		_button_touch.erase(index)
		if act == "guard":
			guarding = false
		for b in _buttons:
			if b.action == act:
				b.node.modulate = Color(1, 1, 1, IDLE_ALPHA)
		_press(act, false)
		used = true
	return used

func _recentre_stick() -> void:
	stick_base.position = _stick_home
	stick_knob.position = _knob_home()

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

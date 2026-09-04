extends Node
## Registers all gameplay input actions in one place (keyboard, gamepad) and tracks
## whether the player is using touch so the mobile overlay can show/hide itself.

const ACTIONS := {
	"move_left": [[KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [JOY_AXIS_LEFT_X, -1.0]],
	"move_right": [[KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [JOY_AXIS_LEFT_X, 1.0]],
	"move_up": [[KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [JOY_AXIS_LEFT_Y, -1.0]],
	"move_down": [[KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [JOY_AXIS_LEFT_Y, 1.0]],
	"attack_light": [[KEY_J, KEY_Z], [JOY_BUTTON_X], null],
	"attack_heavy": [[KEY_K, KEY_X], [JOY_BUTTON_Y], null],
	"jump": [[KEY_L, KEY_SPACE], [JOY_BUTTON_A], null],
	"grab": [[KEY_U, KEY_C], [JOY_BUTTON_B], null],
	"special": [[KEY_I, KEY_V], [JOY_BUTTON_RIGHT_SHOULDER], null],
	"sprint": [[KEY_SHIFT], [JOY_BUTTON_LEFT_SHOULDER], [JOY_AXIS_TRIGGER_LEFT, 1.0]],
	"pause": [[KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], null],
	"menu_confirm": [[KEY_ENTER, KEY_J, KEY_Z, KEY_SPACE], [JOY_BUTTON_A], null],
	"menu_back": [[KEY_ESCAPE, KEY_K, KEY_X, KEY_BACKSPACE], [JOY_BUTTON_B], null],
	"debug_toggle": [[KEY_F1], [], null],
}

var touch_mode: bool = false
var last_device: String = "keyboard"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_actions()
	touch_mode = DisplayServer.is_touchscreen_available() and (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"))
	if touch_mode:
		last_device = "touch"

func _register_actions() -> void:
	for action in ACTIONS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.4)
		var spec: Array = ACTIONS[action]
		for key in spec[0]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		for btn in spec[1]:
			var jb := InputEventJoypadButton.new()
			jb.button_index = btn
			InputMap.action_add_event(action, jb)
		if spec[2] != null:
			var jm := InputEventJoypadMotion.new()
			jm.axis = spec[2][0]
			jm.axis_value = spec[2][1]
			InputMap.action_add_event(action, jm)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not touch_mode:
			touch_mode = true
			last_device = "touch"
			EventBus.touch_mode_changed.emit(true)
	elif event is InputEventKey and event.pressed:
		last_device = "keyboard"
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and absf(event.axis_value) < 0.5:
			return
		last_device = "gamepad"

func get_move_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func is_touch() -> bool:
	return touch_mode

func set_touch_mode(enabled: bool) -> void:
	if touch_mode == enabled:
		return
	touch_mode = enabled
	EventBus.touch_mode_changed.emit(enabled)

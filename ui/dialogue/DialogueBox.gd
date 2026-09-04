extends CanvasLayer
## Reusable dialogue box with portrait, typewriter text, skip, advance and choices.
## Content comes from DialogueData; this node only presents it.

signal line_finished()
signal choice_made(index: int)

const CHARS_PER_SEC := 46.0
const PORTRAIT_DIR := "res://assets/art/ui/portraits/"

var panel: PanelContainer
var name_label: Label
var text_label: RichTextLabel
var portrait: TextureRect
var portrait_frame: PanelContainer
var choice_box: VBoxContainer
var advance_hint: Label

var _full_text: String = ""
var _revealed: float = 0.0
var _typing: bool = false
var _awaiting_choice: bool = false
var _choice_index: int = 0
var _choice_buttons: Array[Button] = []

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide_box()

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.position = Vector2(10, -74)
	panel.custom_minimum_size = Vector2(0, 62)
	panel.offset_left = 10
	panel.offset_right = -10
	panel.offset_top = -74
	panel.offset_bottom = -8
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL, UITheme.BORDER, 2))
	root.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)

	portrait_frame = PanelContainer.new()
	portrait_frame.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.1, 0.09, 0.14), UITheme.BORDER, 1))
	portrait_frame.custom_minimum_size = Vector2(38, 38)
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(portrait_frame)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(32, 32)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_frame.add_child(portrait)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	row.add_child(col)

	name_label = Label.new()
	UITheme.style_label(name_label, 10, UITheme.ACCENT_2)
	col.add_child(name_label)

	text_label = RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.fit_content = false
	text_label.scroll_active = false
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.custom_minimum_size = Vector2(0, 30)
	text_label.add_theme_font_size_override("normal_font_size", 9)
	text_label.add_theme_color_override("default_color", UITheme.TEXT)
	text_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.07))
	text_label.add_theme_constant_override("outline_size", 4)
	col.add_child(text_label)

	advance_hint = Label.new()
	advance_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	advance_hint.text = "▼"
	UITheme.style_label(advance_hint, 9, UITheme.ACCENT_2)
	advance_hint.position = Vector2(-16, -14)
	panel.add_child(advance_hint)

	choice_box = VBoxContainer.new()
	choice_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	choice_box.position = Vector2(-80, -152)
	choice_box.custom_minimum_size = Vector2(160, 0)
	choice_box.add_theme_constant_override("separation", 2)
	choice_box.visible = false
	root.add_child(choice_box)

func show_line(line: Dictionary) -> void:
	visible = true
	panel.visible = true
	_awaiting_choice = false
	choice_box.visible = false
	_clear_choices()
	name_label.text = str(line.get("name", ""))
	name_label.visible = name_label.text != ""
	var pid := str(line.get("portrait", ""))
	if pid == "" and line.has("name"):
		pid = str(line["name"]).to_lower().replace(" ", "_")
	var ppath := PORTRAIT_DIR + pid + ".png"
	if pid != "" and ResourceLoader.exists(ppath):
		portrait.texture = load(ppath)
		portrait_frame.visible = true
	else:
		portrait.texture = null
		portrait_frame.visible = false
	_full_text = str(line.get("text", ""))
	text_label.text = _full_text
	text_label.visible_characters = 0
	_revealed = 0.0
	_typing = true
	advance_hint.visible = false
	AudioManager.play_ui("menu_move")
	if line.has("choices"):
		set_meta("choices", line["choices"])
	else:
		remove_meta("choices") if has_meta("choices") else null

func _process(delta: float) -> void:
	if not visible or not _typing:
		return
	_revealed += delta * CHARS_PER_SEC * (3.0 if _skip_held() else 1.0)
	text_label.visible_characters = int(_revealed)
	if _revealed >= float(_full_text.length()):
		_typing = false
		text_label.visible_characters = -1
		_on_text_complete()

func _skip_held() -> bool:
	return Input.is_action_pressed("menu_confirm") or Input.is_action_pressed("attack_light")

func _on_text_complete() -> void:
	if has_meta("choices"):
		_show_choices(get_meta("choices"))
	else:
		advance_hint.visible = true
		var tw := create_tween()
		tw.set_loops()
		tw.set_ignore_time_scale(true)
		tw.tween_property(advance_hint, "modulate:a", 0.3, 0.5)
		tw.tween_property(advance_hint, "modulate:a", 1.0, 0.5)

func _show_choices(choices: Array) -> void:
	_awaiting_choice = true
	choice_box.visible = true
	_clear_choices()
	for i in choices.size():
		var c: Dictionary = choices[i]
		var b := Button.new()
		b.text = str(c.get("text", "..."))
		UITheme.style_button(b, 10)
		b.pressed.connect(func(): _pick(i))
		choice_box.add_child(b)
		_choice_buttons.append(b)
	if not _choice_buttons.is_empty():
		_choice_index = 0
		_choice_buttons[0].grab_focus()

func _clear_choices() -> void:
	for b in _choice_buttons:
		if is_instance_valid(b):
			b.queue_free()
	_choice_buttons.clear()

func _pick(index: int) -> void:
	if not _awaiting_choice:
		return
	_awaiting_choice = false
	choice_box.visible = false
	_clear_choices()
	AudioManager.play_ui("menu_confirm")
	choice_made.emit(index)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _awaiting_choice:
		if event.is_action_pressed("move_down") or event.is_action_pressed("move_up"):
			var dir := 1 if event.is_action_pressed("move_down") else -1
			_choice_index = wrapi(_choice_index + dir, 0, _choice_buttons.size())
			_choice_buttons[_choice_index].grab_focus()
			AudioManager.play_ui("menu_move")
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("menu_confirm") or event.is_action_pressed("grab"):
			_pick(_choice_index)
			get_viewport().set_input_as_handled()
		return
	var advance := event.is_action_pressed("menu_confirm") or event.is_action_pressed("grab") or event.is_action_pressed("attack_light")
	if event is InputEventScreenTouch and event.pressed:
		advance = true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance = true
	if advance:
		get_viewport().set_input_as_handled()
		if _typing:
			_revealed = float(_full_text.length())
			text_label.visible_characters = -1
			_typing = false
			_on_text_complete()
		else:
			line_finished.emit()

func hide_box() -> void:
	visible = false
	_typing = false
	_awaiting_choice = false
	_clear_choices()
	if choice_box:
		choice_box.visible = false

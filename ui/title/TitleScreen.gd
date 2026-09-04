extends Control
## Title screen: logo, Continue / New Game / Settings / Credits, version stamp.

var buttons: Array[Button] = []
var index: int = 0
var panel_col: VBoxContainer
var info_panel: PanelContainer
var info_col: VBoxContainer
var subtitle: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	GameManager.set_state(GameManager.State.TITLE)
	GameManager.clear_time_effects()
	_build()
	AudioManager.play_music("title")
	AudioManager.play_ambience("")
	if not buttons.is_empty():
		buttons[0].grab_focus()

func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = UITheme.BG
	add_child(bg)

	# Skyline strip behind the logo
	var sky := TextureRect.new()
	if ResourceLoader.exists("res://assets/art/backgrounds/sky_dusk.png"):
		sky.texture = load("res://assets/art/backgrounds/sky_dusk.png")
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.modulate = Color(0.65, 0.6, 0.8)
	add_child(sky)
	var far := TextureRect.new()
	if ResourceLoader.exists("res://assets/art/backgrounds/skyline_near.png"):
		far.texture = load("res://assets/art/backgrounds/skyline_near.png")
	far.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	far.offset_top = -130
	far.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	far.modulate = Color(0.5, 0.45, 0.62)
	add_child(far)

	var title := Label.new()
	title.text = "SIDEWALK KINGS"
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-160, 26)
	title.size = Vector2(320, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(title, 28, UITheme.ACCENT, 6)
	add_child(title)

	subtitle = Label.new()
	subtitle.text = "a Riverbend street story"
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.position = Vector2(-160, 58)
	subtitle.size = Vector2(320, 14)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(subtitle, 10, UITheme.ACCENT_2)
	add_child(subtitle)

	panel_col = VBoxContainer.new()
	panel_col.set_anchors_preset(Control.PRESET_CENTER)
	panel_col.position = Vector2(-62, -8)
	panel_col.custom_minimum_size = Vector2(124, 0)
	panel_col.add_theme_constant_override("separation", 3)
	add_child(panel_col)

	var has_save := SaveManager.has_save(0)
	_add_button("CONTINUE", func(): SceneManager.continue_game(0), not has_save)
	_add_button("NEW GAME", func(): _new_game())
	_add_button("SETTINGS", func(): _show_settings())
	_add_button("CREDITS", func(): _show_credits())

	info_panel = PanelContainer.new()
	info_panel.set_anchors_preset(Control.PRESET_CENTER)
	info_panel.position = Vector2(-110, 24)
	info_panel.custom_minimum_size = Vector2(220, 76)
	info_panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL, UITheme.BORDER, 2))
	info_panel.visible = false
	add_child(info_panel)
	info_col = VBoxContainer.new()
	info_col.add_theme_constant_override("separation", 1)
	info_panel.add_child(info_col)

	if has_save:
		var s := SaveManager.get_save_summary(0)
		var save_info := Label.new()
		save_info.text = "Save: Lv %d  $%d  %s" % [int(s.get("level", 1)), int(s.get("money", 0)), _area_name(str(s.get("area", "")))]
		save_info.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		save_info.position = Vector2(-110, -34)
		save_info.size = Vector2(220, 12)
		save_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.style_label(save_info, 8, UITheme.TEXT_DIM)
		add_child(save_info)

	var version := Label.new()
	version.text = "v" + GameManager.version
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.position = Vector2(-52, -14)
	version.size = Vector2(46, 12)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label(version, 8, UITheme.TEXT_DIM)
	add_child(version)

func _area_name(id: String) -> String:
	var a: AreaData = ContentDB.get_area(id)
	return a.display_name if a else id

func _add_button(text: String, cb: Callable, disabled: bool = false) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	UITheme.style_button(b, 12)
	b.pressed.connect(func():
		AudioManager.play_ui("menu_confirm")
		cb.call())
	panel_col.add_child(b)
	if not disabled:
		buttons.append(b)

func _new_game() -> void:
	if SaveManager.has_save(0):
		_confirm_overwrite()
	else:
		SceneManager.start_new_game()

func _confirm_overwrite() -> void:
	info_panel.visible = true
	for c in info_col.get_children():
		c.queue_free()
	var l := Label.new()
	l.text = "Overwrite your existing save?"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(l, 10, UITheme.BAD)
	info_col.add_child(l)
	var yes := Button.new()
	yes.text = "Yes, start over"
	UITheme.style_button(yes, 10)
	yes.pressed.connect(func():
		SaveManager.delete_save(0)
		SceneManager.start_new_game())
	info_col.add_child(yes)
	var no := Button.new()
	no.text = "Cancel"
	UITheme.style_button(no, 10)
	no.pressed.connect(func():
		info_panel.visible = false
		if not buttons.is_empty():
			buttons[index].grab_focus())
	info_col.add_child(no)
	yes.grab_focus()

func _show_settings() -> void:
	info_panel.visible = true
	for c in info_col.get_children():
		c.queue_free()
	for bus: String in AudioManager.BUSES:
		var h := HBoxContainer.new()
		var l := Label.new()
		l.text = bus
		l.custom_minimum_size = Vector2(60, 0)
		UITheme.style_label(l, 9)
		h.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = AudioManager.get_volume(bus)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.custom_minimum_size = Vector2(110, 12)
		var bus_name: String = bus
		sl.value_changed.connect(func(v):
			AudioManager.set_volume(bus_name, v)
			SaveManager.save_settings())
		h.add_child(sl)
		info_col.add_child(h)
	var close := Button.new()
	close.text = "Back"
	UITheme.style_button(close, 10)
	close.pressed.connect(func():
		info_panel.visible = false
		if not buttons.is_empty():
			buttons[index].grab_focus())
	info_col.add_child(close)

func _show_credits() -> void:
	info_panel.visible = true
	for c in info_col.get_children():
		c.queue_free()
	var l := Label.new()
	l.text = "SIDEWALK KINGS\nAn original beat-'em-up RPG.\n\nCode, art, music and design generated\nfor this project. All characters, places\nand music are original.\n\nBuilt with Godot 4."
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(l, 9, UITheme.TEXT)
	info_col.add_child(l)
	var close := Button.new()
	close.text = "Back"
	UITheme.style_button(close, 10)
	close.pressed.connect(func():
		info_panel.visible = false
		if not buttons.is_empty():
			buttons[index].grab_focus())
	info_col.add_child(close)

func _input(event: InputEvent) -> void:
	if info_panel and info_panel.visible:
		return
	if buttons.is_empty():
		return
	if event.is_action_pressed("move_down") or event.is_action_pressed("move_up"):
		var dir := 1 if event.is_action_pressed("move_down") else -1
		index = wrapi(index + dir, 0, buttons.size())
		buttons[index].grab_focus()
		AudioManager.play_ui("menu_move")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_confirm"):
		buttons[index].emit_signal("pressed")
		get_viewport().set_input_as_handled()

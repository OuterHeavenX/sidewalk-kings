extends CanvasLayer
## One shop UI for every shop type. The list, prices and rules all come from ShopData
## and ShopManager, so adding a shop is adding a data file.

signal closed()

var shop: ShopData = null
var entries: Array[Dictionary] = []
var index: int = 0

var root: Control
var title_label: Label
var owner_label: Label
var money_label: Label
var list_box: VBoxContainer
var desc_label: Label
var detail_label: Label
var speech_label: Label
var buttons: Array[Button] = []

func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.05, 0.72)
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 18
	panel.offset_right = -18
	panel.offset_top = 12
	panel.offset_bottom = -12
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL, UITheme.BORDER, 2))
	root.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	panel.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	col.add_child(header)
	title_label = Label.new()
	UITheme.style_label(title_label, 13, UITheme.ACCENT_2)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	money_label = Label.new()
	UITheme.style_label(money_label, 12, UITheme.GOOD)
	header.add_child(money_label)

	speech_label = Label.new()
	UITheme.style_label(speech_label, 9, UITheme.TEXT_DIM)
	speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech_label.custom_minimum_size = Vector2(0, 12)
	col.add_child(speech_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 1)
	scroll.add_child(list_box)

	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL_DIM, Color(0.3, 0.27, 0.38), 1))
	info.custom_minimum_size = Vector2(0, 34)
	col.add_child(info)
	var icol := VBoxContainer.new()
	icol.add_theme_constant_override("separation", 0)
	info.add_child(icol)
	desc_label = Label.new()
	UITheme.style_label(desc_label, 9, UITheme.TEXT)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	icol.add_child(desc_label)
	detail_label = Label.new()
	UITheme.style_label(detail_label, 9, UITheme.ACCENT_2)
	icol.add_child(detail_label)

	var footer := Label.new()
	UITheme.style_label(footer, 8, UITheme.TEXT_DIM)
	footer.text = "Confirm: J / tap     Leave: ESC / K"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(footer)

	owner_label = Label.new()
	UITheme.style_label(owner_label, 9, UITheme.TEXT_DIM)
	col.add_child(owner_label)
	owner_label.visible = false

func open(data: ShopData) -> void:
	shop = data
	visible = true
	title_label.text = data.display_name
	speech_label.text = data.greeting
	if data.music != "":
		AudioManager.play_music(data.music)
	AudioManager.play_ui("menu_confirm")
	_refresh()

func _refresh() -> void:
	entries = ShopManager.build_entries(shop)
	for b in buttons:
		if is_instance_valid(b):
			b.queue_free()
	buttons.clear()
	money_label.text = "$%d" % GameManager.player_data.money
	for i in entries.size():
		var e: Dictionary = entries[i]
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = _entry_text(e)
		UITheme.style_button(b, 10)
		b.disabled = bool(e.get("owned", false))
		b.pressed.connect(func(): _buy(i))
		b.focus_entered.connect(func(): _focus(i))
		b.mouse_entered.connect(func(): _focus(i))
		list_box.add_child(b)
		buttons.append(b)
	if not buttons.is_empty():
		index = clampi(index, 0, buttons.size() - 1)
		buttons[index].grab_focus()
		_focus(index)

func _entry_text(e: Dictionary) -> String:
	var name := str(e["name"])
	var price := int(e["price"])
	if bool(e.get("owned", false)):
		return "%s   — owned" % name
	if bool(e.get("locked", false)):
		return "%s   $%d  (needs %s)" % [name, price, str(e.get("requirements", "?"))]
	return "%s   $%d" % [name, price]

func _focus(i: int) -> void:
	if i < 0 or i >= entries.size():
		return
	index = i
	var e: Dictionary = entries[i]
	desc_label.text = str(e.get("desc", ""))
	detail_label.text = str(e.get("detail", ""))

func _buy(i: int) -> void:
	if i < 0 or i >= entries.size() or shop == null:
		return
	var e: Dictionary = entries[i]
	var result := ShopManager.purchase(shop, e)
	match result:
		"ok":
			speech_label.text = shop.purchase_lines[randi() % shop.purchase_lines.size()] if shop.purchase_lines.size() > 0 else "Thanks."
		"broke":
			speech_label.text = shop.broke_line
			AudioManager.play_ui("menu_deny")
		"locked":
			speech_label.text = "Not yet. You need %s." % str(e.get("requirements", "more practice"))
			AudioManager.play_ui("menu_deny")
		"owned":
			speech_label.text = "You already have that."
			AudioManager.play_ui("menu_deny")
		"full":
			speech_label.text = "Your hands are full."
			AudioManager.play_ui("menu_deny")
	_refresh()

func close() -> void:
	if not visible:
		return
	visible = false
	speech_label.text = ""
	AudioManager.play_ui("menu_back")
	var meta: AreaData = ContentDB.get_area(GameManager.player_data.current_area)
	if meta:
		AudioManager.play_music(meta.music)
	closed.emit()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("menu_back") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("move_up"):
		if buttons.is_empty():
			return
		var dir := 1 if event.is_action_pressed("move_down") else -1
		index = wrapi(index + dir, 0, buttons.size())
		buttons[index].grab_focus()
		AudioManager.play_ui("menu_move")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_confirm"):
		_buy(index)
		get_viewport().set_input_as_handled()

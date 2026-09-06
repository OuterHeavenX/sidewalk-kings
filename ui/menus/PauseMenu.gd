extends CanvasLayer
## Pause menu with Resume, Inventory, Stats, Techniques, Map, Quests, Settings, Save, Title.

enum Page { ROOT, INVENTORY, STATS, TECHNIQUES, MAP, QUESTS, SAVES, SETTINGS }

var root: Control
var menu_col: VBoxContainer
var page_panel: PanelContainer
var page_col: VBoxContainer
var page_title: Label
var footer: Label
var version_label: Label
var page: Page = Page.ROOT
var buttons: Array[Button] = []
var index: int = 0
## A one-off message like "Game saved." outranks the navigation hint until the page changes.
var _footer_note: String = ""

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.05, 0.76)
	root.add_child(dim)

	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16
	box.offset_right = -16
	box.offset_top = 12
	box.offset_bottom = -12
	box.add_theme_constant_override("separation", 6)
	root.add_child(box)

	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL, UITheme.BORDER, 2))
	left.custom_minimum_size = Vector2(96, 0)
	box.add_child(left)
	menu_col = VBoxContainer.new()
	menu_col.add_theme_constant_override("separation", 2)
	left.add_child(menu_col)

	page_panel = PanelContainer.new()
	page_panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL_DIM, Color(0.3, 0.27, 0.38), 2))
	page_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(page_panel)
	var pc := VBoxContainer.new()
	pc.add_theme_constant_override("separation", 2)
	page_panel.add_child(pc)
	page_title = Label.new()
	UITheme.style_label(page_title, 12, UITheme.ACCENT_2)
	pc.add_child(page_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pc.add_child(scroll)
	page_col = VBoxContainer.new()
	page_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_col.add_theme_constant_override("separation", 1)
	scroll.add_child(page_col)
	var footer_row := HBoxContainer.new()
	footer_row.add_theme_constant_override("separation", 8)
	pc.add_child(footer_row)
	footer = Label.new()
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_label(footer, 8, UITheme.TEXT_DIM)
	footer_row.add_child(footer)
	version_label = Label.new()
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label(version_label, 8, UITheme.TEXT_DIM)
	footer_row.add_child(version_label)

func open() -> void:
	visible = true
	get_tree().paused = true
	GameManager.set_state(GameManager.State.PAUSED)
	AudioManager.play_ui("pause")
	page = Page.ROOT
	if version_label:
		version_label.text = GameManager.version_line()
	_build_menu()
	_show_page(Page.STATS)

func close() -> void:
	visible = false
	get_tree().paused = false
	GameManager.set_state(GameManager.State.PLAYING)
	AudioManager.play_ui("menu_back")

func _build_menu() -> void:
	for b in buttons:
		if is_instance_valid(b):
			b.queue_free()
	buttons.clear()
	var items := [
		["Resume", func(): close()],
		["Stats", func(): _show_page(Page.STATS)],
		["Inventory", func(): _show_page(Page.INVENTORY)],
		["Techniques", func(): _show_page(Page.TECHNIQUES)],
		["Quests", func(): _show_page(Page.QUESTS)],
		["Map", func(): _show_page(Page.MAP)],
		["Settings", func(): _show_page(Page.SETTINGS)],
		["Saves", func(): _show_page(Page.SAVES)],
		["Title", func(): _to_title()],
	]
	for item in items:
		var b := Button.new()
		b.text = str(item[0])
		UITheme.style_button(b, 10)
		var cb: Callable = item[1]
		b.pressed.connect(func():
			AudioManager.play_ui("menu_confirm")
			cb.call())
		menu_col.add_child(b)
		MenuNav.hover_selects(b)
		buttons.append(b)
	index = 0
	if not buttons.is_empty():
		buttons[0].grab_focus()

func _clear_page() -> void:
	for c in page_col.get_children():
		c.queue_free()

func _row(text: String, value: String = "", color: Color = UITheme.TEXT) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_label(l, 9, color)
	h.add_child(l)
	if value != "":
		var v := Label.new()
		v.text = value
		UITheme.style_label(v, 9, UITheme.ACCENT_2)
		h.add_child(v)
	page_col.add_child(h)

func _show_page(p: Page) -> void:
	page = p
	_footer_note = ""
	_clear_page()
	footer.text = ""
	var pd := GameManager.player_data
	match p:
		Page.STATS:
			page_title.text = "Stats"
			_row("Level", str(pd.level))
			_row("XP", "%d / %d" % [pd.xp, pd.xp_to_next_level()])
			_row("Money", "$%d" % pd.money)
			_row("Max HP", str(pd.get_max_hp()))
			page_col.add_child(HSeparator.new())
			for s in PlayerState.STAT_NAMES:
				_row(s.capitalize(), str(pd.stats[s]))
			page_col.add_child(HSeparator.new())
			_row("Punch power", "x%.2f" % pd.get_punch_multiplier())
			_row("Kick power", "x%.2f" % pd.get_kick_multiplier())
			_row("Throw power", "x%.2f" % pd.get_throw_multiplier())
			_row("Weapon skill", "x%.2f" % pd.get_weapon_multiplier())
			_row("Crit chance", "%.0f%%" % (pd.get_crit_chance() * 100.0))
			_row("Playtime", _fmt_time(pd.playtime))
		Page.INVENTORY:
			page_title.text = "Inventory"
			if pd.inventory.is_empty() and pd.key_items.is_empty():
				_row("Nothing but lint.", "", UITheme.TEXT_DIM)
			for id in pd.inventory.keys():
				var res := ContentDB.get_item(str(id))
				var nm := str(res.get("display_name")) if res and res.get("display_name") != null else str(id)
				var b := Button.new()
				b.text = "%s x%d" % [nm, int(pd.inventory[id])]
				b.alignment = HORIZONTAL_ALIGNMENT_LEFT
				UITheme.style_button(b, 9)
				var item_id := str(id)
				b.pressed.connect(func(): _use_item(item_id))
				page_col.add_child(b)
			if not pd.key_items.is_empty():
				page_col.add_child(HSeparator.new())
				_row("Key items", "", UITheme.ACCENT_2)
				for id in pd.key_items:
					var res2 := ContentDB.get_item(str(id))
					_row(str(res2.get("display_name")) if res2 and res2.get("display_name") != null else str(id), "", UITheme.TEXT_DIM)
			_footer_note = "Select an item to use it."
			footer.text = _footer_note
		Page.TECHNIQUES:
			page_title.text = "Techniques"
			for mid in pd.known_moves:
				var m: MoveData = ContentDB.get_move(str(mid))
				if m == null or m.display_name == "":
					continue
				_row(m.display_name, "DMG %d" % m.damage)
			page_col.add_child(HSeparator.new())
			_row("Books read", str(pd.books_read.size()), UITheme.TEXT_DIM)
		Page.QUESTS:
			page_title.text = "Quests"
			# What to do next, at the top, before the quest list. A quest log tells you what
			# you accepted; this tells you where to go, which is the thing a player who has
			# put the game down for a week actually needs.
			_row("Next", "", UITheme.ACCENT)
			var hint_label := Label.new()
			hint_label.text = "  " + HintManager.current_text()
			hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			UITheme.style_label(hint_label, 9, UITheme.TEXT)
			page_col.add_child(hint_label)
			var where := HintManager.current_target()
			if where != "":
				var a: AreaData = ContentDB.get_area(where)
				if a:
					_row("  Head for", a.display_name, UITheme.ACCENT_2)
			page_col.add_child(HSeparator.new())
			var act := QuestManager.active_quests()
			if act.is_empty():
				_row("No active quests.", "", UITheme.TEXT_DIM)
			for q in act:
				var prog := QuestManager.get_progress(q.id)
				_row(q.title, "%d/%d" % [prog, q.required_count], UITheme.ACCENT_2)
				var d := Label.new()
				d.text = "  " + q.description
				d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				UITheme.style_label(d, 8, UITheme.TEXT_DIM)
				page_col.add_child(d)
			var done := QuestManager.completed_quests()
			if not done.is_empty():
				page_col.add_child(HSeparator.new())
				_row("Completed", str(done.size()), UITheme.GOOD)
				for q2 in done:
					_row("  " + q2.title, "", UITheme.TEXT_DIM)
		Page.MAP:
			page_title.text = "Riverbend"
			var map := MapView.new()
			map.custom_minimum_size = Vector2(0, 150)
			map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			page_col.add_child(map)
			await root.get_tree().process_frame
			# Fast travel is refused mid-fight. Walking out of an encounter through a menu
			# would leave the director running an encounter with nobody in it.
			var can_travel: bool = _can_fast_travel()
			await map.build(pd.current_area, can_travel)
			map.travel_requested.connect(_fast_travel)
			_footer_note = ("Enter to travel    Back returns to the menu" if can_travel
				else "You cannot travel in the middle of a fight.")
			footer.text = _footer_note
		Page.SAVES:
			page_title.text = "Saves"
			for slot in range(3):
				var summary: Dictionary = SaveManager.get_save_summary(slot)
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 3)
				var label := Label.new()
				if summary.is_empty():
					label.text = "Slot %d   empty" % (slot + 1)
					UITheme.style_label(label, 9, UITheme.TEXT_DIM)
				else:
					var mins: int = int(float(summary.get("playtime", 0.0)) / 60.0)
					label.text = "Slot %d   Lv %d   $%d   %s   %dm" % [
						slot + 1, int(summary.get("level", 1)), int(summary.get("money", 0)),
						_area_name(str(summary.get("area", ""))), mins]
					UITheme.style_label(label, 9)
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(label)
				var sl: int = slot
				var save_b := Button.new()
				save_b.text = "Save"
				UITheme.style_button(save_b, 9)
				save_b.pressed.connect(func() -> void: _save_to(sl))
				row.add_child(save_b)
				var load_b := Button.new()
				load_b.text = "Load"
				load_b.disabled = summary.is_empty()
				UITheme.style_button(load_b, 9)
				load_b.pressed.connect(func() -> void: _load_from(sl))
				row.add_child(load_b)
				page_col.add_child(row)
			_footer_note = "Three slots. Saving overwrites without asking."
			footer.text = _footer_note
		Page.SETTINGS:
			page_title.text = "Settings"
			for bus: String in AudioManager.BUSES:
				var h := HBoxContainer.new()
				var l := Label.new()
				l.text = bus
				l.custom_minimum_size = Vector2(58, 0)
				UITheme.style_label(l, 9)
				h.add_child(l)
				var sl := HSlider.new()
				sl.min_value = 0.0
				sl.max_value = 1.0
				sl.step = 0.05
				sl.value = AudioManager.get_volume(bus)
				sl.custom_minimum_size = Vector2(90, 12)
				sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var bus_name: String = bus
				sl.value_changed.connect(func(v):
					AudioManager.set_volume(bus_name, v)
					SaveManager.save_settings())
				UITheme.style_slider(sl, h)
				h.add_child(sl)
				page_col.add_child(h)
			page_col.add_child(HSeparator.new())
			var tb := Button.new()
			tb.text = "Touch controls: %s" % ("ON" if InputManager.is_touch() else "OFF")
			UITheme.style_button(tb, 9)
			tb.pressed.connect(func():
				InputManager.set_touch_mode(not InputManager.is_touch())
				_show_page(Page.SETTINGS))
			page_col.add_child(tb)
			# Lights and bloom cost fill rate. The weakest target here is a phone, so
			# this has to be something a player can turn off rather than a fixed cost.
			var lb := Button.new()
			lb.text = "Lighting: %s" % ("ON" if GameManager.lighting_enabled else "OFF")
			UITheme.style_button(lb, 9)
			lb.pressed.connect(func():
				GameManager.lighting_enabled = not GameManager.lighting_enabled
				SaveManager.save_settings()
				# Rebuild so the change is visible immediately rather than at the next door.
				var here: String = GameManager.player_data.current_area
				if here != "":
					SceneManager.reload_area()
				_show_page(Page.SETTINGS))
			page_col.add_child(lb)
			_row("Version", GameManager.version, UITheme.TEXT_DIM)
	# Newly built page controls need hover-to-select too, or the mouse and the keyboard
	# start disagreeing again the moment the page changes.
	await root.get_tree().process_frame
	MenuNav.hover_selects_all(page_col)
	_update_footer()
	_show_root_focus()

func _show_root_focus() -> void:
	if not buttons.is_empty():
		buttons[index].grab_focus()

func _fmt_time(seconds: float) -> String:
	var t := int(seconds)
	return "%d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]

func _use_item(item_id: String) -> void:
	var res := ContentDB.get_item(item_id)
	if res == null:
		return
	if res is FoodData:
		ShopManager.apply_food(res)
		GameManager.add_item(item_id, -1)
		AudioManager.play_sfx("eat", -4.0)
	elif res is ItemData and res.kind == ItemData.Kind.CONSUMABLE:
		if res.heal > 0:
			GameManager.heal_player(res.heal)
		if res.energy > 0 and is_instance_valid(GameManager.player):
			GameManager.player.restore_energy(res.energy)
		if res.flag_on_use != "":
			GameManager.set_flag(res.flag_on_use, true)
		GameManager.add_item(item_id, -1)
		AudioManager.play_sfx("eat", -4.0)
	else:
		AudioManager.play_ui("menu_deny")
		return
	EventBus.item_used.emit(item_id)
	_show_page(Page.INVENTORY)

func _area_name(id: String) -> String:
	var a: AreaData = ContentDB.get_area(id)
	return a.display_name if a else id

## Fast travel is refused while an encounter is live. Leaving through a menu would strand
## the director running a fight with nobody in it, and hand the player a free escape from
## every fight in the game.
func _can_fast_travel() -> bool:
	var area = GameManager.current_area
	if area == null or area.director == null:
		return false
	return not area.director.is_running()

func _fast_travel(area_id: String) -> void:
	if area_id == "" or area_id == GameManager.player_data.current_area:
		return
	if not _can_fast_travel():
		AudioManager.play_ui("menu_deny")
		return
	AudioManager.play_ui("door")
	close()
	SceneManager.change_area(area_id, "start")

func _save_to(slot: int) -> void:
	if SaveManager.save_game(slot):
		AudioManager.play_ui("save")
		_footer_note = "Saved to slot %d." % (slot + 1)
	else:
		AudioManager.play_ui("menu_deny")
		_footer_note = "Could not save: %s" % SaveManager.last_error
	footer.text = _footer_note
	_show_page(Page.SAVES)

func _load_from(slot: int) -> void:
	if not SaveManager.has_save(slot):
		AudioManager.play_ui("menu_deny")
		return
	AudioManager.play_ui("menu_confirm")
	close()
	SceneManager.continue_game(slot)

func _save() -> void:
	if SaveManager.save_game(0):
		AudioManager.play_ui("save")
		_footer_note = "Game saved."
		footer.text = _footer_note

func _to_title() -> void:
	get_tree().paused = false
	visible = false
	SceneManager.goto_title()

## Two columns: the menu list on the left, the current page's own controls on the right.
##
## The page column used to be unreachable. Navigation only ever moved through the left
## column, so the volume sliders and the toggles on the Settings page could be operated
## with a mouse and by nothing else. On a controller, which is how this is played on a
## Steam Deck, the settings simply could not be changed.
func _menu_items() -> Array[Control]:
	return MenuNav.focusables(menu_col)

func _page_items() -> Array[Control]:
	return MenuNav.focusables(page_col)

func _focused() -> Control:
	return root.get_viewport().gui_get_focus_owner()

func _in_page() -> bool:
	var f := _focused()
	return f != null and page_col.is_ancestor_of(f)

func _enter_page() -> bool:
	if MenuNav.focus_first(_page_items()):
		AudioManager.play_ui("menu_move")
		_update_footer()
		return true
	return false

func _leave_page() -> void:
	var items := _menu_items()
	var target: Control = items[index] if index < items.size() else null
	if target:
		target.grab_focus()
	else:
		MenuNav.focus_first(items)
	AudioManager.play_ui("menu_back")
	_update_footer()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	var focused := _focused()
	var in_page := _in_page()

	# Back steps out one level at a time instead of always quitting the menu. Closing the
	# whole thing from deep inside a page was the other half of this feeling awkward.
	if event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu_back"):
		if in_page:
			_leave_page()
		else:
			close()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_down") or event.is_action_pressed("move_up"):
		var dir := 1 if event.is_action_pressed("move_down") else -1
		var list := _page_items() if in_page else _menu_items()
		if MenuNav.step(list, dir, focused):
			AudioManager.play_ui("menu_move")
			if not in_page:
				index = maxi(0, _menu_items().find(_focused()))
			_update_footer()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_right") or event.is_action_pressed("move_left"):
		var dir2 := 1 if event.is_action_pressed("move_right") else -1
		# A focused slider owns left and right, so it can be adjusted at all. Leaving the
		# page is then done with Back, which the footer spells out.
		if in_page and MenuNav.takes_horizontal(focused):
			MenuNav.nudge(focused, dir2)
			AudioManager.play_ui("menu_move")
		elif in_page and dir2 < 0:
			_leave_page()
		elif not in_page and dir2 > 0:
			_enter_page()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("menu_confirm"):
		# Acts on what is actually focused, not on a remembered index that a mouse click
		# may have left pointing somewhere else.
		if MenuNav.activate(focused):
			pass
		elif not in_page:
			_enter_page()
		get_viewport().set_input_as_handled()

## The controls change meaning depending on which column you are in, so say so.
func _update_footer() -> void:
	if _footer_note != "":
		return
	if _in_page():
		var f := _focused()
		if f != null and MenuNav.takes_horizontal(f):
			footer.text = "Left/Right adjust    Back returns to the menu"
		else:
			footer.text = "Up/Down select    Enter use    Back returns to the menu"
	elif _page_items().is_empty():
		footer.text = "Up/Down select    Enter choose    Esc resume"
	else:
		footer.text = "Up/Down select    Right enters the panel    Esc resume"

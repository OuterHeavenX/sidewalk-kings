extends CanvasLayer
## Heads-up display: health, energy, special, money, level/XP, boss bar, notifications,
## interaction prompt and the current quest hint. Built in code so it scales cleanly.

const NOTIFY_TIME := 2.4

var hp_bar: ProgressBar
var energy_bar: ProgressBar
var special_bar: ProgressBar
var xp_bar: ProgressBar
var money_label: Label
var level_label: Label
var weapon_label: Label
var boss_root: Control
var boss_bar: ProgressBar
var boss_name: Label
var notify_root: VBoxContainer
var prompt_root: Control
var prompt_label: Label
var quest_label: Label
var area_label: Label
var combo_label: Label

var _combo: int = 0
var _combo_timer: float = 0.0

func _ready() -> void:
	layer = 10
	_build()
	_connect()
	_refresh_all()

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ---- Left cluster: vitals ----
	var left := VBoxContainer.new()
	left.position = Vector2(8, 6)
	left.add_theme_constant_override("separation", 2)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	left.add_child(name_row)
	level_label = Label.new()
	UITheme.style_label(level_label, 9, UITheme.TEXT)
	name_row.add_child(level_label)
	weapon_label = Label.new()
	UITheme.style_label(weapon_label, 8, UITheme.ACCENT_2)
	name_row.add_child(weapon_label)

	hp_bar = _make_bar(96, 8, UITheme.HP)
	left.add_child(hp_bar)
	energy_bar = _make_bar(80, 5, UITheme.ENERGY)
	left.add_child(energy_bar)
	special_bar = _make_bar(64, 4, UITheme.SPECIAL)
	left.add_child(special_bar)
	xp_bar = _make_bar(64, 3, UITheme.XP)
	left.add_child(xp_bar)

	# ---- Right cluster: money ----
	money_label = Label.new()
	money_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	money_label.position = Vector2(-96, 6)
	money_label.size = Vector2(88, 14)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label(money_label, 12, UITheme.ACCENT_2)
	root.add_child(money_label)

	quest_label = Label.new()
	quest_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quest_label.position = Vector2(-172, 22)
	quest_label.size = Vector2(164, 12)
	quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label(quest_label, 8, UITheme.TEXT_DIM)
	root.add_child(quest_label)

	# ---- Boss bar ----
	boss_root = Control.new()
	boss_root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	boss_root.position = Vector2(0, 22)
	boss_root.custom_minimum_size = Vector2(0, 24)
	boss_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_root.visible = false
	root.add_child(boss_root)
	var bcenter := VBoxContainer.new()
	bcenter.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bcenter.position = Vector2(-90, 0)
	bcenter.custom_minimum_size = Vector2(180, 0)
	bcenter.add_theme_constant_override("separation", 1)
	boss_root.add_child(bcenter)
	boss_name = Label.new()
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name.custom_minimum_size = Vector2(180, 0)
	UITheme.style_label(boss_name, 10, UITheme.ACCENT)
	bcenter.add_child(boss_name)
	boss_bar = _make_bar(180, 8, UITheme.BAD)
	bcenter.add_child(boss_bar)

	# ---- Notifications ----
	notify_root = VBoxContainer.new()
	notify_root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	notify_root.position = Vector2(-90, -68)
	notify_root.custom_minimum_size = Vector2(180, 0)
	notify_root.alignment = BoxContainer.ALIGNMENT_END
	notify_root.add_theme_constant_override("separation", 1)
	notify_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notify_root)

	# ---- Interact prompt ----
	prompt_root = Control.new()
	prompt_root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_root.position = Vector2(-70, -26)
	prompt_root.custom_minimum_size = Vector2(140, 16)
	prompt_root.visible = false
	prompt_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(prompt_root)
	var ppanel := PanelContainer.new()
	ppanel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL_DIM, UITheme.BORDER, 1))
	ppanel.custom_minimum_size = Vector2(140, 0)
	prompt_root.add_child(ppanel)
	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(prompt_label, 9, UITheme.TEXT)
	ppanel.add_child(prompt_label)

	# ---- Area banner ----
	area_label = Label.new()
	area_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	area_label.position = Vector2(-100, 40)
	area_label.size = Vector2(200, 20)
	area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(area_label, 16, UITheme.TEXT, 5)
	area_label.modulate.a = 0.0
	root.add_child(area_label)

	# ---- Combo counter ----
	combo_label = Label.new()
	combo_label.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	combo_label.position = Vector2(10, -20)
	combo_label.size = Vector2(90, 16)
	UITheme.style_label(combo_label, 13, UITheme.ACCENT_2, 5)
	combo_label.modulate.a = 0.0
	root.add_child(combo_label)

func _make_bar(w: int, h: int, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(w, h)
	b.size = Vector2(w, h)
	b.show_percentage = false
	b.max_value = 100
	b.value = 100
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.08, 0.12, 0.88)
	bg.border_color = Color(0.05, 0.04, 0.08)
	bg.set_border_width_all(1)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", UITheme.bar_style(color))
	return b

func _connect() -> void:
	EventBus.player_hp_changed.connect(_on_hp)
	EventBus.player_energy_changed.connect(_on_energy)
	EventBus.player_special_changed.connect(_on_special)
	EventBus.money_changed.connect(_on_money)
	EventBus.xp_changed.connect(_on_xp)
	EventBus.level_up.connect(_on_level_up)
	EventBus.player_stats_changed.connect(_refresh_all)
	EventBus.boss_started.connect(_on_boss_started)
	EventBus.boss_hp_changed.connect(_on_boss_hp)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.area_loading.connect(_on_area_loading)
	EventBus.notification.connect(_on_notify)
	EventBus.area_entered.connect(_on_area)
	EventBus.interactable_focused.connect(_on_focus)
	EventBus.interactable_unfocused.connect(_on_unfocus)
	EventBus.quest_started.connect(func(_id): _refresh_quest())
	EventBus.quest_updated.connect(func(_id): _refresh_quest())
	EventBus.quest_completed.connect(func(_id): _refresh_quest())
	EventBus.hit_landed.connect(_on_hit_landed)
	EventBus.game_state_changed.connect(_on_state)

func _process(delta: float) -> void:
	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_combo = 0
			var tw := create_tween()
			tw.tween_property(combo_label, "modulate:a", 0.0, 0.25)
	var p := GameManager.player
	if is_instance_valid(p):
		weapon_label.text = ""
		if is_instance_valid(p.held_weapon) and p.held_weapon.data:
			weapon_label.text = "[%s x%d]" % [p.held_weapon.data.display_name, p.held_weapon.uses_left]

func _refresh_all() -> void:
	var pd := GameManager.player_data
	_on_hp(pd.hp, pd.get_max_hp())
	_on_money(pd.money, 0)
	_on_xp(pd.xp, pd.xp_to_next_level())
	level_label.text = "Lv %d" % pd.level
	var p := GameManager.player
	if is_instance_valid(p):
		_on_energy(p.energy, p.max_energy)
		_on_special(p.special_meter)
	_refresh_quest()

func _on_state(_s: int) -> void:
	visible = GameManager.state in [GameManager.State.PLAYING, GameManager.State.DIALOGUE, GameManager.State.CUTSCENE]

func _on_hp(hp: int, max_hp: int) -> void:
	hp_bar.max_value = maxi(1, max_hp)
	var tw := create_tween()
	tw.tween_property(hp_bar, "value", float(hp), 0.18)
	var ratio := float(hp) / float(maxi(1, max_hp))
	hp_bar.add_theme_stylebox_override("fill", UITheme.bar_style(UITheme.HP if ratio > 0.3 else Color(1.0, 0.45, 0.2)))

func _on_energy(e: float, max_e: float) -> void:
	energy_bar.max_value = maxf(1.0, max_e)
	energy_bar.value = e

func _on_special(s: float) -> void:
	special_bar.max_value = 100.0
	special_bar.value = s
	special_bar.add_theme_stylebox_override("fill", UITheme.bar_style(UITheme.SPECIAL if s < 100.0 else Color(1.0, 0.85, 0.35)))

func _on_money(total: int, delta: int) -> void:
	money_label.text = "$%d" % total
	if delta > 0:
		var tw := create_tween()
		tw.tween_property(money_label, "scale", Vector2(1.25, 1.25), 0.08)
		tw.tween_property(money_label, "scale", Vector2.ONE, 0.12)

func _on_xp(xp: int, to_next: int) -> void:
	xp_bar.max_value = maxi(1, to_next)
	xp_bar.value = xp
	level_label.text = "Lv %d" % GameManager.player_data.level

func _on_level_up(level: int) -> void:
	AudioManager.play_ui("level_up")
	_notify_text("LEVEL %d!" % level, UITheme.ACCENT_2)

func _on_boss_started(boss: Node) -> void:
	boss_root.visible = true
	boss_name.text = boss.data.display_name if boss.data else "Boss"
	boss_bar.max_value = boss.max_hp
	boss_bar.value = boss.hp
	boss_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(boss_root, "modulate:a", 1.0, 0.4)

func _on_boss_hp(hp: int, max_hp: int) -> void:
	boss_bar.max_value = maxi(1, max_hp)
	var tw := create_tween()
	tw.tween_property(boss_bar, "value", float(hp), 0.15)

## Leaving mid-fight is the case boss_defeated never covers: walk out of a door, or die
## and respawn elsewhere, and the bar would otherwise sit on the HUD for the rest of the
## session showing a boss who is not there.
func _on_area_loading(_area_id: String) -> void:
	boss_root.visible = false
	boss_root.modulate.a = 1.0

func _on_boss_defeated(_b: Node, _id: String) -> void:
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(boss_root, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): boss_root.visible = false)

func _on_notify(text: String, kind: String) -> void:
	var col := UITheme.TEXT
	match kind:
		"quest": col = UITheme.ACCENT_2
		"item", "food": col = UITheme.GOOD
		"error", "warn", "deny": col = UITheme.BAD
		"boss": col = UITheme.ACCENT
		"area": return   # handled by the area banner
	_notify_text(text, col)

func _notify_text(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(180, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(l, 9, color)
	notify_root.add_child(l)
	# Trim old lines. remove_child first: queue_free is deferred, so counting children
	# after it would spin forever.
	while notify_root.get_child_count() > 4:
		var old := notify_root.get_child(0)
		notify_root.remove_child(old)
		old.queue_free()
	var tw := create_tween()
	tw.tween_interval(NOTIFY_TIME)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)

func _on_area(_id: String, name: String) -> void:
	area_label.text = name
	area_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(area_label, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.6)
	tw.tween_property(area_label, "modulate:a", 0.0, 0.6)

func _on_focus(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var text := "Interact"
	if node.has_method("get_interact_prompt"):
		text = node.get_interact_prompt()
	var key := "[Tap]" if InputManager.is_touch() else "[U]"
	prompt_label.text = "%s  %s" % [key, text]
	prompt_root.visible = true

func _on_unfocus(_node: Node) -> void:
	prompt_root.visible = false

func _refresh_quest() -> void:
	var active := QuestManager.active_quests()
	if active.is_empty():
		quest_label.text = ""
		return
	var q: QuestData = active[0]
	var prog := QuestManager.get_progress(q.id)
	if q.required_count > 1:
		quest_label.text = "%s (%d/%d)" % [q.title, prog, q.required_count]
	else:
		quest_label.text = q.title
	if QuestManager.is_ready_to_turn_in(q.id):
		quest_label.text += " *"

func _on_hit_landed(attacker: Node, _target: Node, _dmg: int, _heavy: bool) -> void:
	if attacker == null or not attacker.is_in_group("player"):
		return
	_combo += 1
	_combo_timer = 1.6
	if _combo >= 3:
		combo_label.text = "%d HITS" % _combo
		combo_label.modulate.a = 1.0
		combo_label.scale = Vector2(1.3, 1.3)
		var tw := create_tween()
		tw.tween_property(combo_label, "scale", Vector2.ONE, 0.12)

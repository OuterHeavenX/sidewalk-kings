extends CanvasLayer
## Developer tools. Only reachable when GameManager.debug_enabled is true
## (editor/debug builds, or an export tagged with the "debug_tools" feature).

var col: VBoxContainer
var log_label: Label
var fps_label: Label

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not GameManager.debug_enabled:
		queue_free()
		return
	_build()

func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(6, 60)
	panel.custom_minimum_size = Vector2(122, 0)
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.06, 0.05, 0.09, 0.94), UITheme.ACCENT_2, 1))
	add_child(panel)
	col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	panel.add_child(col)

	var title := Label.new()
	title.text = "DEBUG (F1)"
	UITheme.style_label(title, 9, UITheme.ACCENT_2)
	col.add_child(title)
	fps_label = Label.new()
	UITheme.style_label(fps_label, 8, UITheme.TEXT_DIM)
	col.add_child(fps_label)

	_btn("Give $500", func(): GameManager.add_money(500))
	_btn("Give 500 XP", func(): GameManager.add_xp(500))
	_btn("Heal full", func(): GameManager.heal_player(9999))
	_btn("Fill special", func():
		if is_instance_valid(GameManager.player):
			GameManager.player.add_special(100.0))
	_btn("Spawn grunt", func(): _spawn("pigeon_grunt"))
	_btn("Spawn heavy", func(): _spawn("rust_heavy"))
	_btn("Unlock all moves", func():
		for id in ContentDB.moves.keys():
			GameManager.unlock_move(str(id)))
	_btn("Toggle invincible", func(): _toggle_invuln())
	_btn("Toggle hitboxes", func(): _toggle_shapes())
	_btn("Restart area", func():
		SceneManager.change_area(GameManager.player_data.current_area, "start"))
	_btn("Next area", func(): _next_area())

	log_label = Label.new()
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.custom_minimum_size = Vector2(118, 0)
	UITheme.style_label(log_label, 8, UITheme.GOOD)
	col.add_child(log_label)

func _btn(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UITheme.style_button(b, 8)
	b.pressed.connect(func():
		cb.call()
		_log(text))
	col.add_child(b)

func _log(text: String) -> void:
	if log_label:
		log_label.text = "> " + text

func _process(_delta: float) -> void:
	if fps_label and visible:
		var enemies := get_tree().get_nodes_in_group("enemies").size()
		fps_label.text = "%d fps  enemies:%d" % [Engine.get_frames_per_second(), enemies]

func _spawn(enemy_id: String) -> void:
	var area = GameManager.current_area
	if area and area.director:
		area.director.debug_spawn(enemy_id)

var _invuln := false
func _toggle_invuln() -> void:
	_invuln = not _invuln
	var p := GameManager.player
	if is_instance_valid(p):
		p.hurtbox.active = not _invuln
	_log("Invincible: %s" % _invuln)

var _shapes := false
func _toggle_shapes() -> void:
	_shapes = not _shapes
	get_tree().debug_collisions_hint = _shapes
	# Re-enter the area so the new debug hint takes effect on existing shapes.
	_log("Collision shapes: %s (reload area to apply)" % _shapes)

func _next_area() -> void:
	var ids: Array = ContentDB.areas.keys()
	ids.sort()
	var cur := GameManager.player_data.current_area
	var i := ids.find(cur)
	var nxt := str(ids[(i + 1) % ids.size()]) if not ids.is_empty() else cur
	SceneManager.change_area(nxt, "start")

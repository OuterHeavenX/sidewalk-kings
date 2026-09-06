extends Control
## First scene. Waits one frame so autoloads finish, then hands off to the title screen.
## Also the place to verify content loaded, which catches missing data early.

func _ready() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = UITheme.BG
	add_child(bg)
	var l := Label.new()
	l.text = "SIDEWALK KINGS"
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.position = Vector2(-100, -8)
	l.size = Vector2(200, 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(l, 16, UITheme.ACCENT)
	add_child(l)

	await get_tree().process_frame
	_verify()
	# Automated QA pass:  godot --headless --path . -- --smoke
	var args := OS.get_cmdline_user_args()
	if "--smoke" in args:
		var test = load("res://tests/SmokeTest.gd").new()
		get_tree().root.add_child(test)
		return
	# Audio diagnostic:  godot --path . -- --audio
	if "--audio" in args:
		var ac = load("res://tests/AudioCheck.gd").new()
		get_tree().root.add_child(ac)
		return
	# Full playthrough:  godot --path . -- --play
	# Asks the only question the smoke test cannot: can somebody starting a new game
	# actually reach the end. Those are different questions, and this game has already
	# shipped once with every system green and the first street impossible to leave.
	if "--play" in args:
		var play = load("res://tests/Playthrough.gd").new()
		get_tree().root.add_child(play)
		return
	# Visual capture pass:  godot --path . -- --shots
	if "--shots" in args:
		var shots = load("res://tests/ScreenshotTool.gd").new()
		get_tree().root.add_child(shots)
		return
	await get_tree().create_timer(0.25).timeout
	SceneManager.goto_title()

func _verify() -> void:
	var problems: PackedStringArray = []
	if ContentDB.moves.is_empty():
		problems.append("no moves loaded")
	if ContentDB.enemies.is_empty():
		problems.append("no enemies loaded")
	if ContentDB.areas.is_empty():
		problems.append("no area metadata loaded")
	if not ResourceLoader.exists("res://assets/art/characters/kip_frames.tres"):
		problems.append("player sprite frames missing")
	if problems.is_empty():
		print("[Boot] content OK")
	else:
		push_warning("[Boot] content problems: " + ", ".join(problems))

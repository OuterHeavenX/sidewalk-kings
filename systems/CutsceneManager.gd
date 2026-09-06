extends Node
## Runs scripted scenes: camera moves, actor blocking, dialogue, and the flags they set.
##
## A cutscene is a JSON list of steps in res://data/cutscenes/<id>.json, the same shape and
## for the same reason as an area layout: it is a sequence of instructions, not a set of
## properties, and it changes far more often than the code that runs it.
##
## Taking control is almost free here, because the player already gates its own input on
## GameManager.is_gameplay_active(). Setting the state to CUTSCENE stops the player, the
## enemy director and the encounter triggers without any of them needing to know why.
##
## Every step is skippable and the whole scene is abortable, because a cutscene that traps
## the player is worse than no cutscene at all. `abort()` runs the remaining flag and quest
## steps before it returns, so skipping never leaves the story half-advanced.

signal cutscene_started(id: String)
signal cutscene_finished(id: String)

const DIR := "res://data/cutscenes/"

var playing: String = ""
var _abort: bool = false
var _steps: Array = []
var _index: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func is_playing() -> bool:
	return playing != ""

func exists(id: String) -> bool:
	return FileAccess.file_exists(DIR + id + ".json")

func load_steps(id: String) -> Array:
	if not exists(id):
		return []
	var f := FileAccess.open(DIR + id + ".json", FileAccess.READ)
	if f == null:
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary and (parsed as Dictionary).has("steps"):
		return (parsed as Dictionary)["steps"]
	if parsed is Array:
		return parsed
	return []

## Play a cutscene to the end. Safe to await.
func play(id: String) -> void:
	if is_playing():
		return
	_steps = load_steps(id)
	if _steps.is_empty():
		push_warning("[Cutscene] nothing to play for '%s'" % id)
		return
	playing = id
	_abort = false
	_index = 0
	var prev_state: int = GameManager.state
	GameManager.set_state(GameManager.State.CUTSCENE)
	cutscene_started.emit(id)

	while _index < _steps.size():
		var step: Dictionary = _steps[_index]
		_index += 1
		if _abort:
			# Still apply anything that changes the story, so skipping cannot desync it.
			_apply_state_only(step)
			continue
		await _run(step)

	_release_camera()
	playing = ""
	GameManager.set_state(GameManager.State.PLAYING if prev_state == GameManager.State.CUTSCENE else prev_state)
	if GameManager.state != GameManager.State.PLAYING:
		GameManager.set_state(GameManager.State.PLAYING)
	cutscene_finished.emit(id)

## Stop early. The remaining flags and quests are still applied.
## True once a skip has been asked for and before the scene has unwound. Anything a step is
## awaiting -- a comic, in particular -- has to be able to see this and stop.
func is_aborting() -> bool:
	return _abort

func abort() -> void:
	if is_playing():
		_abort = true
		if DialogueManager.is_active():
			DialogueManager._finish()

func _release_camera() -> void:
	var area = GameManager.current_area
	if area and area.camera:
		area.camera.release()

# ---------------------------------------------------------------- steps
func _run(step: Dictionary) -> void:
	match str(step.get("do", "")):
		"wait":
			await _sleep(float(step.get("time", 0.5)))
		"say":
			await _say(str(step.get("dialogue", "")))
		"comic":
			await _comic(str(step.get("id", "")))
		"camera":
			await _camera(step)
		"move":
			await _move(step)
		"face":
			var a := _actor(str(step.get("actor", "player")))
			if a:
				a.set("facing", int(step.get("dir", 1)))
		"anim":
			var a2 := _actor(str(step.get("actor", "player")))
			if a2 and a2.has_method("play_anim"):
				a2.play_anim(str(step.get("name", "idle")), true, false)
		"shake":
			EventBus.screen_shake.emit(float(step.get("amount", 2.0)), 0.3)
		"sfx":
			AudioManager.play_sfx(str(step.get("id", "")))
		"music":
			AudioManager.play_music(str(step.get("id", "")))
		"fade":
			await _fade(float(step.get("to", 1.0)), float(step.get("time", 0.4)))
		_:
			_apply_state_only(step)

## Flags and quests: the parts of a step that change the game rather than show it. Applied
## whether the scene is watched or skipped.
func _apply_state_only(step: Dictionary) -> void:
	match str(step.get("do", "")):
		"flag":
			GameManager.set_flag(str(step.get("name", "")), step.get("value", true))
		"quest":
			if step.has("start"):
				QuestManager.start_quest(str(step["start"]))
			if step.has("complete"):
				QuestManager.complete_quest(str(step["complete"]))
		_:
			pass

## Hand the screen to the comic player and wait for it.
##
## The player is created on demand rather than living in the scene: comics are rare, and a
## CanvasLayer that exists for the whole game is a thing that can be left visible.
func _comic(comic_id: String) -> void:
	if comic_id == "":
		return
	var player = load("res://ui/ComicPlayer.gd").new()
	get_tree().root.add_child(player)
	await player.play(comic_id)
	player.queue_free()

func _sleep(seconds: float) -> void:
	# Frame-counted rather than a timer: a SceneTreeTimer does not fire while the tree is
	# paused, and a cutscene has to be able to run through a pause-adjacent state.
	var frames := int(maxf(1.0, seconds * 60.0))
	for i in frames:
		if _abort:
			return
		await get_tree().process_frame

func _say(dialogue_id: String) -> void:
	if dialogue_id == "" or not ContentDB.dialogues.has(dialogue_id):
		return
	DialogueManager.start(dialogue_id)
	var guard := 0
	while DialogueManager.is_active() and not _abort and guard < 3600:
		await get_tree().process_frame
		guard += 1

func _camera(step: Dictionary) -> void:
	var area = GameManager.current_area
	if area == null or area.camera == null:
		return
	if bool(step.get("follow", false)):
		area.camera.release()
		return
	var to := Vector2(
		float(step.get("x", area.camera.global_position.x)),
		float(step.get("y", area.camera.global_position.y)))
	var seconds := float(step.get("time", 1.0))
	area.camera.focus(to, seconds)
	await _sleep(seconds)

func _move(step: Dictionary) -> void:
	var a := _actor(str(step.get("actor", "player")))
	if a == null:
		return
	var to_x := float(step.get("x", a.global_position.x))
	var seconds := maxf(0.05, float(step.get("time", 1.0)))
	var from := a.global_position.x
	if a.has_method("play_anim") and not is_equal_approx(from, to_x):
		a.play_anim("walk", false, false)
		a.set("facing", 1 if to_x > from else -1)
	var frames := int(seconds * 60.0)
	for i in frames:
		if _abort:
			break
		var t := float(i + 1) / float(frames)
		a.global_position.x = lerpf(from, to_x, t)
		await get_tree().process_frame
	a.global_position.x = to_x
	if a.has_method("play_anim"):
		a.play_anim("idle", false, false)

func _fade(to: float, seconds: float) -> void:
	if to > 0.5:
		await SceneManager.fade_out(seconds)
	else:
		await SceneManager.fade_in(seconds)

## "player" or an npc_id. Returns null rather than erroring: a scene that names an actor
## who is not in this area should skip that step, not bring the whole thing down.
func _actor(name: String) -> Node2D:
	if name == "player" or name == "":
		return GameManager.player as Node2D
	for n in get_tree().get_nodes_in_group("npcs"):
		if n.get("npc_id") == name:
			return n as Node2D
	for n in get_tree().get_nodes_in_group("enemies"):
		if n.get("data") != null and n.data.id == name:
			return n as Node2D
	return null

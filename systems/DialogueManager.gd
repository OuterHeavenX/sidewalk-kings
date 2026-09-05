extends Node
## Interprets DialogueData and drives the DialogueBox UI. Dialogue content lives in data resources.

const BOX_SCENE := "res://ui/dialogue/DialogueBox.tscn"

var active: bool = false
var _box: Node = null
var _data: DialogueData = null
var _index: int = 0
var _previous_state: int = GameManager.State.PLAYING
var _context_npc: String = ""
var _finished_callback: Callable = Callable()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ensure_box() -> void:
	if _box != null and is_instance_valid(_box):
		return
	if not ResourceLoader.exists(BOX_SCENE):
		push_error("[DialogueManager] Missing DialogueBox scene")
		return
	_box = load(BOX_SCENE).instantiate()
	_box.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_box)
	_box.line_finished.connect(_on_line_finished)
	_box.choice_made.connect(_on_choice_made)

func is_active() -> bool:
	return active

## Start a dialogue by id (from ContentDB) or by passing a DialogueData directly.
func start(dialogue: Variant, npc_id: String = "", on_finished: Callable = Callable()) -> void:
	if active:
		return
	var data: DialogueData = dialogue if dialogue is DialogueData else ContentDB.get_dialogue(str(dialogue))
	if data == null:
		push_warning("[DialogueManager] Unknown dialogue: %s" % str(dialogue))
		return
	_ensure_box()
	if _box == null:
		return
	_data = data
	_index = 0
	_context_npc = npc_id
	_finished_callback = on_finished
	active = true
	_previous_state = GameManager.state
	if data.pause_game:
		GameManager.set_state(GameManager.State.DIALOGUE)
	EventBus.dialogue_started.emit(data.id)
	_show_line()

## Convenience: show a one-off line without a resource.
func say(name: String, text: String, portrait: String = "") -> void:
	var d := DialogueData.new()
	d.id = "_adhoc"
	d.lines = [{"name": name, "text": text, "portrait": portrait}]
	start(d)

func _show_line() -> void:
	while _index < _data.lines.size():
		var line: Dictionary = _data.lines[_index]
		if not _line_allowed(line):
			_index += 1
			continue
		_apply_line_effects(line)
		if line.has("text"):
			_box.show_line(line)
			return
		if line.has("goto"):
			_index = int(line["goto"])
			continue
		if line.get("end", false):
			break
		_index += 1
	_finish()

func _line_allowed(line: Dictionary) -> bool:
	if line.has("if_flag") and not GameManager.get_flag(str(line["if_flag"])):
		return false
	if line.has("if_not_flag") and GameManager.get_flag(str(line["if_not_flag"])):
		return false
	if line.has("if_quest_state"):
		var spec: Array = line["if_quest_state"]
		if QuestManager.get_state(str(spec[0])) != str(spec[1]):
			return false
	if line.has("if_has_item") and not GameManager.has_item(str(line["if_has_item"])):
		return false
	if line.has("if_min_money") and GameManager.player_data.money < int(line["if_min_money"]):
		return false
	return true

func _apply_line_effects(line: Dictionary) -> void:
	if line.has("set_flag"):
		GameManager.set_flag(str(line["set_flag"]), line.get("flag_value", true))
	if line.has("start_quest"):
		QuestManager.start_quest(str(line["start_quest"]))
	if line.has("complete_quest"):
		QuestManager.complete_quest(str(line["complete_quest"]))
	if line.has("give_item"):
		GameManager.add_item(str(line["give_item"]), int(line.get("count", 1)))
		GameManager.notify("Got %s" % _item_name(str(line["give_item"])), "item")
	if line.has("give_key_item"):
		GameManager.add_key_item(str(line["give_key_item"]))
		GameManager.notify("Got %s" % _item_name(str(line["give_key_item"])), "item")
	if line.has("take_key_item"):
		GameManager.remove_key_item(str(line["take_key_item"]))
	if line.has("give_money"):
		GameManager.add_money(int(line["give_money"]))
	if line.has("take_money"):
		GameManager.spend_money(int(line["take_money"]))
	if line.has("unlock_move"):
		GameManager.unlock_move(str(line["unlock_move"]))
	if line.has("heal"):
		GameManager.heal_player(int(line["heal"]))
	if line.has("sfx"):
		AudioManager.play_ui(str(line["sfx"]))
	if line.has("shop"):
		call_deferred("_open_shop_after", str(line["shop"]))

func _item_name(id: String) -> String:
	var res := ContentDB.get_item(id)
	if res and res.get("display_name") != null:
		return str(res.get("display_name"))
	return id.capitalize()

var _pending_shop: String = ""
func _open_shop_after(shop_id: String) -> void:
	_pending_shop = shop_id

func _on_line_finished() -> void:
	var line: Dictionary = _data.lines[_index]
	if line.has("choices"):
		return  # waiting for choice
	if line.get("end", false):
		_finish()
		return
	if line.has("goto"):
		_index = int(line["goto"])
	else:
		_index += 1
	_show_line()

func _on_choice_made(choice_index: int) -> void:
	var line: Dictionary = _data.lines[_index]
	var choices: Array = line.get("choices", [])
	EventBus.dialogue_choice.emit(_data.id, choice_index)
	if choice_index < 0 or choice_index >= choices.size():
		_index += 1
		_show_line()
		return
	var choice: Dictionary = choices[choice_index]
	_apply_line_effects(choice)
	if choice.get("end", false):
		_finish()
		return
	if choice.has("goto"):
		_index = int(choice["goto"])
	else:
		_index += 1
	_show_line()

func _finish() -> void:
	var id := _data.id if _data else ""
	if _data and _data.once_flag != "":
		GameManager.set_flag(_data.once_flag, true)
	active = false
	if _box:
		_box.hide_box()
	if GameManager.state == GameManager.State.DIALOGUE:
		GameManager.set_state(GameManager.State.PLAYING)
	EventBus.dialogue_ended.emit(id)
	var cb := _finished_callback
	_finished_callback = Callable()
	_data = null
	if _context_npc != "":
		QuestManager.notify_talked_to(_context_npc)
	_context_npc = ""
	# is_valid() stays true for a callable whose object has since been freed, which is what
	# happens when a scene is torn down mid-dialogue. Asking for the object to check it is
	# itself the thing that prints the error, so the id is checked instead: that never
	# dereferences anything.
	var cb_obj_id := cb.get_object_id()
	if cb.is_valid() and (cb_obj_id == 0 or is_instance_id_valid(cb_obj_id)):
		cb.call()
	if _pending_shop != "":
		var s := _pending_shop
		_pending_shop = ""
		ShopManager.open_shop(s)

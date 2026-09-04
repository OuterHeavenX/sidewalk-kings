extends Node
## Tracks quest state in GameManager.player_data.quests. Quest definitions come from ContentDB.
## quests[id] = {"state": "active"|"ready"|"done", "progress": int}

func _ready() -> void:
	EventBus.enemy_defeated.connect(_on_enemy_defeated)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.item_acquired.connect(_on_item_acquired)
	EventBus.area_entered.connect(_on_area_entered)
	EventBus.flag_set.connect(_on_flag_set)

func _quests() -> Dictionary:
	return GameManager.player_data.quests

func get_state(quest_id: String) -> String:
	return str(_quests().get(quest_id, {}).get("state", "none"))

func get_progress(quest_id: String) -> int:
	return int(_quests().get(quest_id, {}).get("progress", 0))

func is_active(quest_id: String) -> bool:
	return get_state(quest_id) in ["active", "ready"]

func is_done(quest_id: String) -> bool:
	return get_state(quest_id) == "done"

func is_ready_to_turn_in(quest_id: String) -> bool:
	return get_state(quest_id) == "ready"

func start_quest(quest_id: String) -> void:
	var q: QuestData = ContentDB.get_quest(quest_id)
	if q == null or get_state(quest_id) != "none":
		return
	_quests()[quest_id] = {"state": "active", "progress": 0}
	EventBus.quest_started.emit(quest_id)
	GameManager.notify("New quest: " + q.title, "quest")
	AudioManager.play_ui("quest_start")
	# Objectives that may already be satisfied (e.g. item already owned).
	_recheck(quest_id)

func add_progress(quest_id: String, amount: int = 1) -> void:
	if get_state(quest_id) != "active":
		return
	var q: QuestData = ContentDB.get_quest(quest_id)
	var entry: Dictionary = _quests()[quest_id]
	entry["progress"] = mini(int(entry["progress"]) + amount, q.required_count)
	EventBus.quest_updated.emit(quest_id)
	if int(entry["progress"]) >= q.required_count:
		_objective_met(quest_id)
	else:
		GameManager.notify("%s (%d/%d)" % [q.title, int(entry["progress"]), q.required_count], "quest")

func _objective_met(quest_id: String) -> void:
	var q: QuestData = ContentDB.get_quest(quest_id)
	if q.turn_in_npc == "":
		complete_quest(quest_id)
	else:
		_quests()[quest_id]["state"] = "ready"
		EventBus.quest_updated.emit(quest_id)
		GameManager.notify("%s: objective complete!" % q.title, "quest")

func complete_quest(quest_id: String) -> void:
	var q: QuestData = ContentDB.get_quest(quest_id)
	if q == null or get_state(quest_id) == "done":
		return
	if get_state(quest_id) == "none":
		_quests()[quest_id] = {"state": "active", "progress": q.required_count}
	_quests()[quest_id]["state"] = "done"
	if q.reward_money > 0:
		GameManager.add_money(q.reward_money)
	if q.reward_xp > 0:
		GameManager.add_xp(q.reward_xp)
	for item in q.reward_items:
		GameManager.add_item(item, 1)
	if q.reward_move != "":
		GameManager.unlock_move(q.reward_move)
	if q.reward_flag != "":
		GameManager.set_flag(q.reward_flag, true)
	EventBus.quest_completed.emit(quest_id)
	GameManager.notify("Quest complete: " + q.title, "quest")
	AudioManager.play_ui("quest_complete")

func active_quests() -> Array[QuestData]:
	var out: Array[QuestData] = []
	for id in _quests().keys():
		if is_active(id):
			var q: QuestData = ContentDB.get_quest(id)
			if q:
				out.append(q)
	return out

func completed_quests() -> Array[QuestData]:
	var out: Array[QuestData] = []
	for id in _quests().keys():
		if is_done(id):
			var q: QuestData = ContentDB.get_quest(id)
			if q:
				out.append(q)
	return out

func _recheck(quest_id: String) -> void:
	var q: QuestData = ContentDB.get_quest(quest_id)
	match q.objective:
		QuestData.Objective.COLLECT_ITEM, QuestData.Objective.DELIVER_ITEM:
			var have := GameManager.item_count(q.target) + (1 if q.target in GameManager.player_data.key_items else 0)
			if have > 0:
				_set_progress(quest_id, mini(have, q.required_count))
		QuestData.Objective.FLAG:
			if GameManager.get_flag(q.target):
				_set_progress(quest_id, q.required_count)
		QuestData.Objective.DEFEAT_BOSS:
			if q.target in GameManager.player_data.bosses_defeated:
				_set_progress(quest_id, q.required_count)

func _set_progress(quest_id: String, value: int) -> void:
	if get_state(quest_id) != "active":
		return
	var q: QuestData = ContentDB.get_quest(quest_id)
	_quests()[quest_id]["progress"] = value
	EventBus.quest_updated.emit(quest_id)
	if value >= q.required_count:
		_objective_met(quest_id)

# ---- Event hooks ----
func _for_each_active(callback: Callable) -> void:
	for id in _quests().keys():
		if get_state(id) == "active":
			var q: QuestData = ContentDB.get_quest(id)
			if q:
				callback.call(q)

func _on_enemy_defeated(enemy: Node, enemy_id: String) -> void:
	var gang: String = enemy.get("gang_id") if enemy.get("gang_id") != null else ""
	_for_each_active(func(q: QuestData):
		if q.objective == QuestData.Objective.DEFEAT_GANG and q.target == gang:
			add_progress(q.id)
		elif q.objective == QuestData.Objective.DEFEAT_ENEMY_ID and q.target == enemy_id:
			add_progress(q.id))

func _on_boss_defeated(_boss: Node, boss_id: String) -> void:
	_for_each_active(func(q: QuestData):
		if q.objective == QuestData.Objective.DEFEAT_BOSS and q.target == boss_id:
			add_progress(q.id, q.required_count))

func _on_item_acquired(item_id: String, count: int) -> void:
	if count <= 0:
		return
	_for_each_active(func(q: QuestData):
		if (q.objective == QuestData.Objective.COLLECT_ITEM or q.objective == QuestData.Objective.DELIVER_ITEM) and q.target == item_id:
			_recheck(q.id))

func _on_area_entered(area_id: String, _name: String) -> void:
	_for_each_active(func(q: QuestData):
		if q.objective == QuestData.Objective.REACH_AREA and q.target == area_id:
			add_progress(q.id, q.required_count))

func _on_flag_set(flag: String, value: Variant) -> void:
	if not value:
		return
	_for_each_active(func(q: QuestData):
		if q.objective == QuestData.Objective.FLAG and q.target == flag:
			add_progress(q.id, q.required_count))

## Called by NPCs when the player talks to them.
func notify_talked_to(npc_id: String) -> void:
	_for_each_active(func(q: QuestData):
		if q.objective == QuestData.Objective.TALK_TO and q.target == npc_id:
			add_progress(q.id, q.required_count))
	# Turn-ins
	for id in _quests().keys():
		if get_state(id) == "ready":
			var q: QuestData = ContentDB.get_quest(id)
			if q and q.turn_in_npc == npc_id:
				if q.objective == QuestData.Objective.DELIVER_ITEM:
					if q.target in GameManager.player_data.key_items:
						GameManager.remove_key_item(q.target)
					else:
						GameManager.add_item(q.target, -q.required_count)
				complete_quest(id)

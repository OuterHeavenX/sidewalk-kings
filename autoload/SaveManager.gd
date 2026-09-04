extends Node
## Versioned JSON save system. Uses user:// which maps to IndexedDB on the Web export.

const SAVE_VERSION := 1
const SAVE_DIR := "user://saves/"
const SETTINGS_PATH := "user://settings.json"
const SLOT_COUNT := 3

var last_error: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	load_settings()

func slot_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.json" % slot

func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(slot_path(slot))

func get_save_summary(slot: int = 0) -> Dictionary:
	var data := _read_json(slot_path(slot))
	if data.is_empty():
		return {}
	var p: Dictionary = data.get("player", {})
	return {
		"level": int(p.get("level", 1)),
		"money": int(p.get("money", 0)),
		"area": str(p.get("current_area", "?")),
		"playtime": float(p.get("playtime", 0.0)),
		"timestamp": str(data.get("timestamp", "")),
		"version": int(data.get("save_version", 0)),
	}

func save_game(slot: int = 0) -> bool:
	var pd := GameManager.player_data
	if is_instance_valid(GameManager.player) and GameManager.player.has_method("sync_to_data"):
		GameManager.player.sync_to_data()
	var payload := {
		"save_version": SAVE_VERSION,
		"game_version": GameManager.version,
		"timestamp": Time.get_datetime_string_from_system(),
		"player": pd.to_dict(),
	}
	var ok := _write_json(slot_path(slot), payload)
	if ok:
		EventBus.game_saved.emit(slot)
		GameManager.notify("Game saved", "save")
	else:
		GameManager.notify("Save failed: " + last_error, "error")
	return ok

func load_game(slot: int = 0) -> bool:
	var data := _read_json(slot_path(slot))
	if data.is_empty():
		last_error = "No save data"
		return false
	data = migrate(data)
	var pd := PlayerState.new()
	pd.from_dict(data.get("player", {}))
	GameManager.player_data = pd
	EventBus.game_loaded.emit(slot)
	return true

func delete_save(slot: int = 0) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(slot_path(slot))

## Upgrade old save dictionaries to the current schema, one version step at a time.
func migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("save_version", 0))
	while v < SAVE_VERSION:
		match v:
			0:
				# Pre-versioned saves: wrap raw player dictionaries.
				if not data.has("player"):
					data = {"player": data}
				v = 1
			_:
				v += 1
		data["save_version"] = v
	return data

# ---------------- Settings ----------------
func save_settings() -> void:
	var payload := {
		"version": 1,
		"audio": AudioManager.settings_to_dict(),
		"touch_controls": InputManager.touch_mode,
		"screen_shake": GameManager.get("screen_shake_scale") if GameManager.get("screen_shake_scale") != null else 1.0,
	}
	_write_json(SETTINGS_PATH, payload)

func load_settings() -> void:
	var data := _read_json(SETTINGS_PATH)
	if data.is_empty():
		return
	if data.has("audio"):
		AudioManager.settings_from_dict(data["audio"])

# ---------------- IO ----------------
func _write_json(path: String, data: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		last_error = "Cannot open %s (%s)" % [path, error_string(FileAccess.get_open_error())]
		push_error("[SaveManager] " + last_error)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		last_error = "Cannot read %s" % path
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	last_error = "Corrupt save file: " + path
	push_error("[SaveManager] " + last_error)
	return {}

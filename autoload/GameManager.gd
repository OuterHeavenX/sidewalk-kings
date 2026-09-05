extends Node
## Central game state: version, state machine, player data, feel effects (hit stop / slow-mo).

enum State { BOOT, TITLE, PLAYING, PAUSED, DIALOGUE, SHOP, CUTSCENE, MENU, GAME_OVER }

var version: String = "0.0.0"
var state: State = State.BOOT
var player_data: PlayerState = PlayerState.new()
var player: Node = null
var current_area: Node = null
var debug_enabled: bool = false
var difficulty: float = 1.0
## Lights and bloom cost fill rate, and the weakest target here is a phone. Off makes
## every area build unlit, which is exactly how the game looked before lighting existed.
var lighting_enabled: bool = true

var _hitstop_until_ms: int = 0
var _slowmo_until_ms: int = 0
var _slowmo_scale: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	version = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	# Debug tools only in editor/debug builds, or when exported with the "debug_tools" feature tag.
	debug_enabled = OS.is_debug_build() or OS.has_feature("debug_tools")
	EventBus.hit_stop.connect(_on_hit_stop)
	EventBus.slow_motion.connect(_on_slow_motion)
	print("[GameManager] Sidewalk Kings v%s ready (debug=%s)" % [version, debug_enabled])

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _hitstop_until_ms > 0:
		if now >= _hitstop_until_ms:
			_hitstop_until_ms = 0
			Engine.time_scale = _slowmo_scale if now < _slowmo_until_ms else 1.0
	elif _slowmo_until_ms > 0 and now >= _slowmo_until_ms:
		_slowmo_until_ms = 0
		_slowmo_scale = 1.0
		Engine.time_scale = 1.0
	if state == State.PLAYING:
		player_data.playtime += delta / maxf(Engine.time_scale, 0.001)

# ---------------- State ----------------
func set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	EventBus.game_state_changed.emit(new_state)

func is_gameplay_active() -> bool:
	return state == State.PLAYING

func is_frozen() -> bool:
	return Time.get_ticks_msec() < _hitstop_until_ms

# ---------------- Feel ----------------
func _on_hit_stop(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	if until > _hitstop_until_ms:
		_hitstop_until_ms = until
	Engine.time_scale = 0.0

func _on_slow_motion(scale: float, seconds: float) -> void:
	_slowmo_scale = scale
	_slowmo_until_ms = Time.get_ticks_msec() + int(seconds * 1000.0)
	if _hitstop_until_ms == 0:
		Engine.time_scale = scale

func clear_time_effects() -> void:
	_hitstop_until_ms = 0
	_slowmo_until_ms = 0
	_slowmo_scale = 1.0
	Engine.time_scale = 1.0

# ---------------- Player data helpers ----------------
func new_game() -> void:
	player_data = PlayerState.new()
	clear_time_effects()

func add_money(amount: int) -> void:
	player_data.money = maxi(0, player_data.money + amount)
	EventBus.money_changed.emit(player_data.money, amount)

func spend_money(amount: int) -> bool:
	if player_data.money < amount:
		return false
	add_money(-amount)
	return true

func add_xp(amount: int) -> void:
	player_data.xp += amount
	var leveled := false
	while player_data.xp >= player_data.xp_to_next_level():
		player_data.xp -= player_data.xp_to_next_level()
		player_data.level += 1
		leveled = true
		_apply_level_up()
	EventBus.xp_changed.emit(player_data.xp, player_data.xp_to_next_level())
	if leveled:
		EventBus.level_up.emit(player_data.level)
		EventBus.player_stats_changed.emit()

func _apply_level_up() -> void:
	# Modest baseline growth. Most growth comes from shops, food, books and training.
	var lvl: int = player_data.level
	player_data.stats.strength += 1
	player_data.stats.stamina += 1
	if lvl % 2 == 0:
		player_data.stats.defense += 1
		player_data.stats.speed += 1
	if lvl % 3 == 0:
		player_data.stats.technique += 1
		player_data.stats.luck += 1
	player_data.hp = player_data.get_max_hp()
	player_data.energy = player_data.get_max_energy()
	EventBus.player_hp_changed.emit(player_data.hp, player_data.get_max_hp())
	if is_instance_valid(player) and player.has_method("sync_from_data"):
		player.sync_from_data()

func add_stat(stat: String, amount: int) -> void:
	if not player_data.stats.has(stat):
		return
	player_data.stats[stat] = clampi(int(player_data.stats[stat]) + amount, 1, 99)
	EventBus.player_stats_changed.emit()
	if is_instance_valid(player) and player.has_method("sync_from_data"):
		player.sync_from_data()

func add_bonus(bonus: String, amount: int) -> void:
	if not player_data.bonuses.has(bonus):
		return
	player_data.bonuses[bonus] = int(player_data.bonuses[bonus]) + amount
	EventBus.player_stats_changed.emit()
	if is_instance_valid(player) and player.has_method("sync_from_data"):
		player.sync_from_data()

func set_flag(flag: String, value: Variant = true) -> void:
	player_data.flags[flag] = value
	EventBus.flag_set.emit(flag, value)

func get_flag(flag: String, default: Variant = false) -> Variant:
	return player_data.flags.get(flag, default)

func has_move(move_id: String) -> bool:
	return move_id in player_data.known_moves

func unlock_move(move_id: String) -> void:
	if has_move(move_id):
		return
	player_data.known_moves.append(move_id)
	EventBus.move_unlocked.emit(move_id)
	EventBus.player_stats_changed.emit()

func add_item(item_id: String, count: int = 1) -> void:
	player_data.inventory[item_id] = int(player_data.inventory.get(item_id, 0)) + count
	if int(player_data.inventory[item_id]) <= 0:
		player_data.inventory.erase(item_id)
	EventBus.item_acquired.emit(item_id, count)

func item_count(item_id: String) -> int:
	return int(player_data.inventory.get(item_id, 0))

func has_item(item_id: String) -> bool:
	return item_count(item_id) > 0 or item_id in player_data.key_items

func add_key_item(item_id: String) -> void:
	if item_id in player_data.key_items:
		return
	player_data.key_items.append(item_id)
	EventBus.item_acquired.emit(item_id, 1)

func remove_key_item(item_id: String) -> void:
	player_data.key_items.erase(item_id)

func heal_player(amount: int) -> void:
	player_data.hp = clampi(player_data.hp + amount, 0, player_data.get_max_hp())
	EventBus.player_hp_changed.emit(player_data.hp, player_data.get_max_hp())
	if is_instance_valid(player) and player.has_method("sync_from_data"):
		player.sync_from_data()

func notify(text: String, kind: String = "info") -> void:
	EventBus.notification.emit(text, kind)

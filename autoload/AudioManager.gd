extends Node
## Audio playback with bus categories (Master, Music, SFX, UI, Ambience), pooled SFX players,
## music cross-fade and per-bus volume settings persisted by SaveManager.

const BUSES := ["Master", "Music", "SFX", "UI", "Ambience"]
const SFX_POOL_SIZE := 12
const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const AMBIENCE_DIR := "res://assets/audio/ambience/"

var volumes: Dictionary = {"Master": 0.9, "Music": 0.7, "SFX": 0.9, "UI": 0.8, "Ambience": 0.6}
var current_music: String = ""
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _ui_pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _last_play_ms: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	_music_active = _music_a
	_ambience = _make_player("Ambience")
	for i in SFX_POOL_SIZE:
		_sfx_pool.append(_make_player("SFX"))
	for i in 4:
		_ui_pool.append(_make_player("UI"))
	apply_volumes()

func _ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")

func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	return p

# ---------------- Volume ----------------
func set_volume(bus: String, linear: float) -> void:
	volumes[bus] = clampf(linear, 0.0, 1.0)
	apply_volumes()
	EventBus.settings_changed.emit()

func get_volume(bus: String) -> float:
	return float(volumes.get(bus, 1.0))

func apply_volumes() -> void:
	for b in BUSES:
		var idx := AudioServer.get_bus_index(b)
		if idx == -1:
			continue
		var v := float(volumes.get(b, 1.0))
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(idx, v <= 0.001)

# ---------------- Loading ----------------
func _load_stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	_cache[path] = stream
	return stream

func _resolve(dir: String, id: String) -> AudioStream:
	for ext in [".ogg", ".wav", ".mp3"]:
		var s := _load_stream(dir + id + ext)
		if s:
			return s
	return null

# ---------------- SFX ----------------
func play_sfx(id: String, volume_db: float = 0.0, pitch_variance: float = 0.06, min_interval_ms: int = 30) -> void:
	var now := Time.get_ticks_msec()
	if _last_play_ms.has(id) and now - int(_last_play_ms[id]) < min_interval_ms:
		return
	_last_play_ms[id] = now
	var stream := _resolve(SFX_DIR, id)
	if stream == null:
		return
	var p := _get_free(_sfx_pool)
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	p.play()

func play_ui(id: String, volume_db: float = 0.0) -> void:
	var stream := _resolve(SFX_DIR, id)
	if stream == null:
		return
	var p := _get_free(_ui_pool)
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0
	p.play()

func _get_free(pool: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	for p in pool:
		if not p.playing:
			return p
	var oldest: AudioStreamPlayer = pool[0]
	for p in pool:
		if p.get_playback_position() > oldest.get_playback_position():
			oldest = p
	return oldest

# ---------------- Music ----------------
func play_music(id: String, fade: float = 0.8) -> void:
	if id == current_music:
		return
	current_music = id
	var stream := _resolve(MUSIC_DIR, id)
	var next: AudioStreamPlayer = _music_b if _music_active == _music_a else _music_a
	var prev: AudioStreamPlayer = _music_active
	_music_active = next
	if stream == null:
		_fade_out(prev, fade)
		return
	next.stream = stream
	next.volume_db = -40.0
	next.play()
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(next, "volume_db", 0.0, fade)
	_fade_out(prev, fade)

func stop_music(fade: float = 0.6) -> void:
	current_music = ""
	_fade_out(_music_active, fade)

func _fade_out(p: AudioStreamPlayer, fade: float) -> void:
	if not p.playing:
		return
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(p, "volume_db", -40.0, fade)
	tw.tween_callback(p.stop)

# ---------------- Ambience ----------------
func play_ambience(id: String) -> void:
	var stream := _resolve(AMBIENCE_DIR, id)
	if stream == null:
		_ambience.stop()
		return
	if _ambience.stream == stream and _ambience.playing:
		return
	_ambience.stream = stream
	_ambience.play()

func stop_ambience() -> void:
	_ambience.stop()

func settings_to_dict() -> Dictionary:
	return volumes.duplicate()

func settings_from_dict(d: Dictionary) -> void:
	for k in d.keys():
		if volumes.has(k):
			volumes[k] = clampf(float(d[k]), 0.0, 1.0)
	apply_volumes()

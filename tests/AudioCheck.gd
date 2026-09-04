extends Node
## Audio diagnostic. Run with a real audio driver (not --headless, which uses the Dummy
## driver and reports playback that never actually happened):
##
##   godot --path . -- --audio
##
## Reports bus wiring, volumes, whether every referenced sound resolves to a real stream,
## and whether players actually enter a playing state.

var problems: Array[String] = []

func _ready() -> void:
	print("\n=== AUDIO CHECK ===")
	print("driver: ", AudioServer.get_driver_name(), "   mix rate: ", AudioServer.get_mix_rate(),
		"   output latency: ", AudioServer.get_output_latency())
	print("output device: ", AudioServer.output_device)
	await get_tree().process_frame
	_report_buses()
	await _report_streams()
	await _report_playback()
	print("\n=== %s ===\n" % ("AUDIO OK" if problems.is_empty() else "AUDIO PROBLEMS:\n  - " + "\n  - ".join(problems)))
	get_tree().quit(0 if problems.is_empty() else 1)

func fail(msg: String) -> void:
	problems.append(msg)

func _report_buses() -> void:
	print("\n-- Buses --")
	print("bus count: ", AudioServer.bus_count)
	for i in AudioServer.bus_count:
		var name: String = AudioServer.get_bus_name(i)
		var db: float = AudioServer.get_bus_volume_db(i)
		var muted: bool = AudioServer.is_bus_mute(i)
		var send: String = str(AudioServer.get_bus_send(i)) if i > 0 else "-"
		print("  [%d] %-10s %7.2f dB  muted=%s  send=%s" % [i, name, db, muted, send])
		if muted:
			fail("bus '%s' is muted" % name)
		if db < -50.0:
			fail("bus '%s' is effectively silent at %.1f dB" % [name, db])
	for b in AudioManager.BUSES:
		if AudioServer.get_bus_index(b) == -1:
			fail("bus '%s' does not exist" % b)
	print("AudioManager volumes: ", AudioManager.volumes)

func _report_streams() -> void:
	print("\n-- Stream resolution --")
	# Everything the game actually asks for by name.
	var sfx_ids: Array[String] = [
		"punch_light", "punch_heavy", "kick", "whoosh_light", "whoosh_heavy",
		"hit_light", "hit_heavy", "hit_weapon", "hit_crit", "block", "throw", "land",
		"jump", "step", "hurt", "enemy_hurt", "enemy_defeat", "knockdown", "money",
		"pickup", "purchase", "eat", "menu_move", "menu_confirm", "menu_back",
		"menu_deny", "level_up", "quest_start", "quest_complete", "unlock",
		"weapon_pickup", "weapon_break", "break_object", "door", "boss_warning",
		"telegraph", "special_charge", "special_hit", "dash", "grab", "notify",
		"save", "pause",
	]
	var missing_sfx: Array[String] = []
	for id in sfx_ids:
		if AudioManager._resolve(AudioManager.SFX_DIR, id) == null:
			missing_sfx.append(id)
	print("sfx resolved: %d/%d" % [sfx_ids.size() - missing_sfx.size(), sfx_ids.size()])
	if not missing_sfx.is_empty():
		fail("sfx that do not resolve: " + ", ".join(missing_sfx))

	var music_ids: Array[String] = ["title", "street", "market", "alley", "industrial", "boss", "victory", "shop"]
	var missing_music: Array[String] = []
	for id in music_ids:
		if AudioManager._resolve(AudioManager.MUSIC_DIR, id) == null:
			missing_music.append(id)
	print("music resolved: %d/%d" % [music_ids.size() - missing_music.size(), music_ids.size()])
	if not missing_music.is_empty():
		fail("music that does not resolve: " + ", ".join(missing_music))

	# Every area's declared music and ambience must exist.
	for id in ContentDB.areas.keys():
		var a: AreaData = ContentDB.areas[id]
		if a.music != "" and AudioManager._resolve(AudioManager.MUSIC_DIR, a.music) == null:
			fail("area '%s' wants music '%s' which does not resolve" % [id, a.music])
		if a.ambience != "" and AudioManager._resolve(AudioManager.AMBIENCE_DIR, a.ambience) == null:
			fail("area '%s' wants ambience '%s' which does not resolve" % [id, a.ambience])

	# Report what a resolved stream actually is, which catches a bad import.
	var s: AudioStream = AudioManager._resolve(AudioManager.MUSIC_DIR, "street")
	if s:
		print("street music: ", s.get_class(), "  length: %.2fs" % s.get_length())
		if s.get_length() <= 0.1:
			fail("music stream 'street' has no length; the import produced an empty sample")

func _report_playback() -> void:
	print("\n-- Playback --")
	AudioManager.play_music("street")
	await get_tree().create_timer(0.5).timeout
	var mp: AudioStreamPlayer = AudioManager._music_active
	print("music player: stream=%s playing=%s vol=%.1fdB bus=%s pos=%.2f" % [
		mp.stream, mp.playing, mp.volume_db, mp.bus, mp.get_playback_position()])
	if mp.stream == null:
		fail("music player has no stream after play_music()")
	elif not mp.playing:
		fail("music player is not playing after play_music()")
	elif mp.get_playback_position() <= 0.0:
		fail("music playback position never advanced")

	AudioManager.play_sfx("punch_heavy")
	await get_tree().process_frame
	var any_sfx := false
	for p in AudioManager._sfx_pool:
		if p.playing:
			any_sfx = true
	print("an sfx player is playing: ", any_sfx)
	if not any_sfx:
		fail("no sfx player started after play_sfx()")

	AudioManager.play_ambience("city")
	await get_tree().process_frame
	print("ambience playing: ", AudioManager._ambience.playing)
	if not AudioManager._ambience.playing:
		fail("ambience did not start")

	# Music must loop, or a track simply stops after its first pass.
	var stream: AudioStream = AudioManager._resolve(AudioManager.MUSIC_DIR, "street")
	if stream is AudioStreamWAV:
		var w: AudioStreamWAV = stream
		print("street loop mode: ", w.loop_mode, "  (0 = disabled)")
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			fail("music 'street' is imported with looping disabled, so it plays once and stops")

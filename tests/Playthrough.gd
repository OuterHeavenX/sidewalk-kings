extends Node
## Plays Sidewalk Kings from New Game to the end credits and reports whether it can be
## finished.
##
##     godot --path . -- --play
##
## This is not the smoke test. The smoke test asks whether each system works in isolation;
## this asks the only question that actually matters to a player, which is whether the
## sequence of gates that make up the story can be opened in order by someone starting a
## new game. Those are different questions, and the game has already shipped once with
## every system green and the first street impossible to leave.
##
## The bot plays honestly: it walks with the movement actions, fights with the attack
## actions, talks to NPCs through their interact method, and opens doors by standing in
## them. It never sets a story flag itself. If a flag is not set, the game did not set it,
## and that is a real failure of the route.
##
## The one concession is death: dying is not the same as the game being unfinishable, so the
## bot is revived and put back where it was. Every revival is counted and reported, because
## a route that needs forty is telling you something about the difficulty curve.

const STEP_TIMEOUT := 150.0        # seconds of real time before a single objective is failed
const MAX_REVIVES := 60

var log_lines: PackedStringArray = []
var failures: PackedStringArray = []
var revives := 0
var started_at := 0.0

## Stuck detection. A street has solid props and standing NPCs in it, and walking straight
## at one holds you there forever. A player steps around; the bot has to as well, or the
## run reports the game as unfinishable when the truth is that a bench was in the way.
var _last_gap := 1e9
var _still_ticks := 0
var _detour := 0
var _detour_dir := 1.0
var _last_report := 0.0
var _layout_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	started_at = Time.get_ticks_msec() / 1000.0
	await get_tree().process_frame
	await run()

func say(text: String) -> void:
	log_lines.append(text)
	print(text)

func note(text: String) -> void:
	say("    " + text)

func fail(text: String) -> void:
	failures.append(text)
	say("  [STUCK] " + text)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout

func player() -> Player:
	return GameManager.player

# ---------------------------------------------------------------- the run
func run() -> void:
	say("=== SIDEWALK KINGS PLAYTHROUGH ===")
	SceneManager.start_new_game()
	await seconds(2.0)

	await chapter_one()
	await chapter_two()
	await chapter_three()

	var elapsed := Time.get_ticks_msec() / 1000.0 - started_at
	say("")
	say("--- Result ---")
	say("  in-game time      %s" % _clock())
	say("  wall clock        %.0fs" % elapsed)
	say("  revives           %d" % revives)
	say("  level reached     %d" % GameManager.player_data.level)
	say("  money             $%d" % GameManager.player_data.money)
	var done: bool = GameManager.get_flag("chapter_3_done")
	say("  chapter 1 done    %s" % GameManager.get_flag("chapter_1_done"))
	say("  chapter 2 done    %s" % GameManager.get_flag("chapter_2_done"))
	say("  chapter 3 done    %s" % done)
	if failures.is_empty() and done:
		say("=== THE GAME CAN BE FINISHED ===")
	else:
		say("=== THE GAME COULD NOT BE FINISHED ===")
		for f in failures:
			say("  - " + f)
	_write_report()
	await frames(2)
	get_tree().quit(0 if (failures.is_empty() and done) else 1)

## Wait for a story flag rather than sampling it once.
##
## Arrival flags come from cutscenes that start a frame or two after the area finishes
## loading and then run for several seconds. Sampling immediately reported chapter two as
## broken when the scene that sets it had not begun.
func _await_flag(flag_name: String, timeout: float = 25.0) -> bool:
	if flag_name == "":
		return true
	var deadline := Time.get_ticks_msec() / 1000.0 + timeout
	while Time.get_ticks_msec() / 1000.0 < deadline:
		if GameManager.get_flag(flag_name):
			return true
		# A cutscene that is still running is the game working, not the game stuck. The
		# Line Office arrival is 17 steps with three conversations and a timed camera move
		# in it, and a fixed deadline expired in the middle and called the chapter broken.
		if CutsceneManager.is_playing():
			deadline = Time.get_ticks_msec() / 1000.0 + timeout
		await settle()
		await frames(4)
	return GameManager.get_flag(flag_name)

func _clock() -> String:
	var t := int(GameManager.player_data.playtime)
	return "%d:%02d" % [t / 60, t % 60]

func _write_report() -> void:
	var f := FileAccess.open("user://playthrough.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.close()
		print("[play] report -> ", ProjectSettings.globalize_path("user://playthrough.txt"))

# ---------------------------------------------------------------- chapters
func chapter_one() -> void:
	say("")
	say("-- Chapter one --")
	await talk_to("dez", "the premise", "knows_premise")
	await clear_area("ferry_row")
	await goto("ferry_row")
	await talk_to("dez", "hand in the Pigeons")
	# The dens. Optional content, walked deliberately: a boss nobody ever reaches is the
	# same as a boss that does not exist, and this is the only thing that would notice.
	await goto("ferry_office")
	await clear_area("ferry_office", "tally_beaten")
	await goto("lantern_market")
	await clear_area("lantern_market")
	await goto("wool_back")
	await clear_area("wool_back", "vell_beaten")
	# Dez hands out the next job each time, and the game does not say so. Walking back is
	# the intended loop, and it is also exactly where a player gets lost.
	await goto("ferry_row")
	await talk_to("dez", "ask what is next")
	await goto("grease_alley")
	await clear_area("grease_alley")
	await goto("grease_workshop")
	await clear_area("grease_workshop", "crank_beaten")
	await goto("ferry_row")
	await talk_to("dez", "ask what is next")
	await goto("rustpile_yard")
	await clear_area("rustpile_yard", "yard_cleared")
	await goto("scrap_office")
	await clear_area("scrap_office", "skip_beaten")
	# All four reasons heard; Dez is the one who adds them up.
	await goto("ferry_row")
	await talk_to("dez", "what the four reasons add up to", "knows_why")
	await goto("starch_laundromat")
	await clear_area("starch_laundromat", "chapter_1_done")

func chapter_two() -> void:
	say("")
	say("-- Chapter two --")
	await goto("ferry_row")
	await talk_to("dez", "ask about the metro", "metro_open")
	await goto("metro_platform")
	await clear_area("metro_platform")
	await search_props("metro_platform")
	await goto("bellwater_block")
	await clear_area("bellwater_block", "bellwater_cleared")
	await goto("line_office", "chapter_2_done")

func chapter_three() -> void:
	say("")
	say("-- Chapter three --")
	await talk_to("line_manager", "take the form", "took_the_form")
	await goto("ferry_row")
	await talk_to("dez", "tell Dez about the form", "told_dez_ch3")
	await goto("service_stair")
	await clear_area("service_stair")
	await goto("line_four")
	await clear_area("line_four", "line_four_cleared")
	await goto("substation")
	await clear_area("substation", "foreman_beaten")
	if not failures.is_empty():
		return
	await seconds(3.0)
	await settle()
	if not GameManager.get_flag("chapter_3_done"):
		fail("beat the Foreman but chapter_3_done was never set")

# ---------------------------------------------------------------- objectives
## Head for an area from wherever we currently are, routing over the door graph.
##
## Locked doors are excluded from the route rather than walked into, so "no way there" and
## "the way there is shut" are different failures and the report says which.
func goto(dest: String, expect_flag: String = "") -> void:
	if not failures.is_empty():
		return
	await settle()
	var guard := 0
	while GameManager.player_data.current_area != dest and guard < 24:
		guard += 1
		var here: String = GameManager.player_data.current_area
		var route := _route(here, dest)
		if route.size() < 2:
			fail("no open route from %s to %s (locked doors: %s)"
				% [here, dest, ", ".join(_locked_from(here))])
			return
		await travel(here, String(route[1]))
		if not failures.is_empty():
			return
		await settle()
	if GameManager.player_data.current_area != dest:
		fail("gave up routing to %s after %d hops" % [dest, guard])
		return
	if expect_flag != "" and not await _await_flag(expect_flag):
		fail("reaching %s did not set '%s'" % [dest, expect_flag])

## Breadth-first over the areas, using only doors that are currently open.
func _route(from: String, to: String) -> Array:
	if from == to:
		return [from]
	var queue: Array = [[from]]
	var seen := {from: true}
	while not queue.is_empty():
		var path: Array = queue.pop_front()
		var tail := String(path[-1])
		for nxt in _open_exits(tail):
			if seen.has(nxt):
				continue
			seen[nxt] = true
			var next_path: Array = path.duplicate()
			next_path.append(nxt)
			if nxt == to:
				return next_path
			queue.append(next_path)
	return []

## Where you can actually get to from an area right now. Read from the layout rather than
## from AreaData.connections, because the layout is what carries the locks.
func _open_exits(area_id: String) -> Array:
	var out: Array = []
	var layout := _layout(area_id)
	for d in layout.get("doors", []):
		var to := str(d.get("to", ""))
		if to == "":
			continue
		var need := str(d.get("required_flag", ""))
		if need != "" and not GameManager.get_flag(need):
			continue
		out.append(to)
	return out

func _locked_from(area_id: String) -> Array:
	var out: Array = []
	for d in _layout(area_id).get("doors", []):
		var need := str(d.get("required_flag", ""))
		if need != "" and not GameManager.get_flag(need):
			out.append("%s needs %s" % [d.get("to", "?"), need])
	return out

func _layout(area_id: String) -> Dictionary:
	if _layout_cache.has(area_id):
		return _layout_cache[area_id]
	var path := "res://data/areas/%s.json" % area_id
	var out: Dictionary = {}
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Dictionary:
			out = parsed
	_layout_cache[area_id] = out
	return out

## Walk into the door leading to `to` and confirm arrival.
func travel(from: String, to: String, expect_flag: String = "") -> void:
	if not failures.is_empty():
		return
	await settle()
	# Street edges are automatic doors, so sweeping a street can carry you into the next one
	# before the script asks. Arriving early is arriving.
	if GameManager.player_data.current_area == to:
		note("%s -> %s (walked out of the street while clearing it)" % [from, to])
		if expect_flag != "" and not GameManager.get_flag(expect_flag):
			fail("arriving in %s did not set '%s'" % [to, expect_flag])
		return
	if GameManager.player_data.current_area != from:
		fail("expected to be in %s to reach %s, but was in %s"
			% [from, to, GameManager.player_data.current_area])
		return
	var door := _find_door_to(to)
	if door == null:
		fail("no door from %s to %s" % [from, to])
		return
	if door.required_flag != "" and not GameManager.get_flag(door.required_flag):
		fail("the door from %s to %s is locked: needs '%s'" % [from, to, door.required_flag])
		return

	var deadline := Time.get_ticks_msec() / 1000.0 + STEP_TIMEOUT
	while GameManager.player_data.current_area != to:
		if Time.get_ticks_msec() / 1000.0 > deadline:
			fail("could not get from %s to %s within %ds" % [from, to, int(STEP_TIMEOUT)])
			_release()
			return
		if not is_instance_valid(door):
			break
		await _step_towards(door.global_position, true)
		# Street edges open by walking into them; every other door wants the interact key.
		# Only walking is how the bot stood in a shop doorway for ninety seconds.
		var pl := player()
		var close_enough: bool = pl != null and is_instance_valid(pl) \
			and pl.global_position.distance_to(door.global_position) < 22.0
		if not door.auto and close_enough and GameManager.is_gameplay_active():
			door.interact(player())
			await frames(4)
			await settle()
		if _fighting():
			await fight()
		await _revive_if_dead()
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_report > 6.0:
			_last_report = now
			var pp := player()
			if not is_instance_valid(door):
				break
			note("  ...to %s: x=%.0f y=%.0f door=(%.0f, %.0f) auto=%s state=%d"
				% [to,
				pp.global_position.x if is_instance_valid(pp) else -1.0,
				pp.global_position.y if is_instance_valid(pp) else -1.0,
				door.global_position.x, door.global_position.y,
				str(door.auto), GameManager.state])
	_release()
	await settle()
	if GameManager.player_data.current_area == to:
		note("%s -> %s" % [from, to])
	if expect_flag != "" and not GameManager.get_flag(expect_flag):
		fail("arriving in %s did not set '%s'" % [to, expect_flag])

## Walk the whole street, fighting everything that starts.
func clear_area(area_id: String, expect_flag: String = "") -> void:
	if not failures.is_empty():
		return
	await settle()
	if GameManager.player_data.current_area != area_id:
		fail("expected to be clearing %s, but was in %s"
			% [area_id, GameManager.player_data.current_area])
		return
	var area = GameManager.current_area
	if area == null:
		fail("no area loaded while clearing %s" % area_id)
		return
	var deadline := Time.get_ticks_msec() / 1000.0 + STEP_TIMEOUT * 4.0
	var fights := 0
	# Sweep the street so every encounter trigger is crossed, but stop well short of both
	# ends: the edges are automatic doors, and walking into one leaves the area mid-clear,
	# after which the loop is chasing an x coordinate in a street that no longer exists.
	var far: float = area.walk_max_x - 90.0
	var near: float = area.walk_min_x + 90.0
	for target_x in [far, near, far]:
		_last_gap = 1e9
		_still_ticks = 0
		_detour = 0
		while is_instance_valid(player()) and absf(player().global_position.x - target_x) > 30.0:
			# Street edges are automatic doors, so a sweep can walk you into the next area.
			# Go back and carry on rather than abandoning the street: giving up here left
			# the Rustpile Yard's second encounter untriggered, so yard_cleared never set
			# and chapter one stopped, for no reason to do with the game.
			if GameManager.player_data.current_area != area_id:
				note("left %s early; walking back" % area_id)
				await goto(area_id)
				if not failures.is_empty():
					return
				_last_gap = 1e9
				_still_ticks = 0
				_detour = 0
				continue
			if Time.get_ticks_msec() / 1000.0 > deadline:
				fail("could not finish clearing %s within %ds (stopped at x=%.0f heading for %.0f)"
					% [area_id, int(STEP_TIMEOUT * 4.0),
					player().global_position.x if is_instance_valid(player()) else -1.0, target_x])
				_release()
				return
			await _step_towards(Vector2(target_x, player().global_position.y), false)
			if _fighting():
				fights += 1
				await fight()
			await _revive_if_dead()
			# Telemetry, because a bot that stops has to be able to say why. Five runs were
			# spent guessing at obstacles that turned out not to be solid.
			var now := Time.get_ticks_msec() / 1000.0
			if now - _last_report > 6.0:
				_last_report = now
				var pp := player()
				note("  ...%s x=%.0f y=%.0f -> %.0f | fight=%s enemies=%d state=%d hp=%d detour=%d still=%d"
					% [area_id,
					pp.global_position.x if is_instance_valid(pp) else -1.0,
					pp.global_position.y if is_instance_valid(pp) else -1.0,
					target_x, str(_fighting()),
					get_tree().get_nodes_in_group("enemies").size(),
					GameManager.state,
					pp.hp if is_instance_valid(pp) else -1,
					_detour, _still_ticks])
		_release()
		if _fighting():
			fights += 1
			await fight()
	_release()
	await settle()
	note("cleared %s (%d fights)" % [area_id, fights])
	if expect_flag != "" and not await _await_flag(expect_flag):
		fail("clearing %s did not set '%s'" % [area_id, expect_flag])

## Fight until the director says the encounter is over.
func fight() -> void:
	var deadline := Time.get_ticks_msec() / 1000.0 + STEP_TIMEOUT * 2.0
	while _fighting():
		if Time.get_ticks_msec() / 1000.0 > deadline:
			# Say what the fight looked like when it would not end, or the next run is spent
			# guessing which of the enemies was the problem.
			var alive: Array[String] = []
			var pp := player()
			for en in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(en) and not en.dead:
					alive.append("%s hp=%d at %.0f,%.0f%s" % [en.enemy_id, en.hp,
						en.global_position.x, en.global_position.y,
						" state=%d" % en.ai_state if en.get("ai_state") != null else ""])
			fail("a fight in %s never ended; player at %.0f,%.0f vs [%s]"
				% [GameManager.player_data.current_area,
				pp.global_position.x if is_instance_valid(pp) else -1.0,
				pp.global_position.y if is_instance_valid(pp) else -1.0,
				"; ".join(alive)])
			return
		await _revive_if_dead()
		if DialogueManager.is_active():
			await _advance_dialogue()
			continue
		var target := _nearest_enemy()
		if target == null:
			await frames(4)
			continue
		var p := player()
		if p == null or not is_instance_valid(p):
			await frames(4)
			continue
		# Line up in the lane, close the gap, then swing.
		var dy: float = target.global_position.y - p.global_position.y
		var dx: float = target.global_position.x - p.global_position.x
		if absf(dy) > 5.0:
			_hold("move_down" if dy > 0.0 else "move_up")
			await frames(3)
			_release()
		elif absf(dx) > 26.0:
			_hold("move_right" if dx > 0.0 else "move_left")
			await frames(4)
			_release()
		else:
			p.facing = 1 if dx >= 0.0 else -1
			p._press_attack(MoveData.InputKind.HEAVY if randf() < 0.3
				else MoveData.InputKind.LIGHT)
			await frames(9)
	_release()
	await settle()

## Talk to an NPC by id, in whatever state the story has them in.
func talk_to(npc_id: String, what: String, expect_flag: String = "") -> void:
	if not failures.is_empty():
		return
	await settle()
	var npc := _find_npc(npc_id)
	if npc == null:
		fail("could not find %s in %s to %s"
			% [npc_id, GameManager.player_data.current_area, what])
		return
	var deadline := Time.get_ticks_msec() / 1000.0 + STEP_TIMEOUT
	while player() != null and player().global_position.distance_to(npc.global_position) > 20.0:
		if Time.get_ticks_msec() / 1000.0 > deadline:
			fail("could not reach %s to %s" % [npc_id, what])
			_release()
			return
		await _step_towards(npc.global_position, true)
		await _revive_if_dead()
	_release()
	npc.interact(player())
	await _advance_dialogue()
	await settle()
	note("talked to %s (%s)" % [npc_id, what])
	if expect_flag != "" and not await _await_flag(expect_flag, 8.0):
		fail("talking to %s to %s did not set '%s'" % [npc_id, what, expect_flag])

## Search every searchable prop in the area. The Tuesday locker is a story gate hidden in one.
func search_props(area_id: String) -> void:
	if not failures.is_empty():
		return
	# Clearing a street can walk you out of it, so make sure we are back in the one whose
	# props we mean to search. The first version searched whatever area it happened to be
	# standing in and reported "0 props" from the wrong street.
	await goto(area_id)
	if not failures.is_empty():
		return
	await settle()
	if GameManager.current_area == null:
		fail("no area loaded to search in %s" % area_id)
		return
	var found := 0
	for n in GameManager.current_area.actors_root.get_children():
		if not n.has_method("interact") or not n.get("searchable"):
			continue
		var deadline := Time.get_ticks_msec() / 1000.0 + 30.0
		while player() != null and player().global_position.distance_to(n.global_position) > 20.0:
			if Time.get_ticks_msec() / 1000.0 > deadline:
				break
			await _step_towards(n.global_position, true)
		_release()
		n.interact(player())
		await _advance_dialogue()
		found += 1
	note("searched %d props in %s" % [found, area_id])

# ---------------------------------------------------------------- helpers
func _fighting() -> bool:
	var area = GameManager.current_area
	return area != null and area.director != null and area.director.is_running()

func _nearest_enemy() -> Node2D:
	var p := player()
	if p == null or not is_instance_valid(p):
		return null
	var best: Node2D = null
	var best_d := 1e9
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = p.global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _hold(action: String) -> void:
	_release()
	Input.action_press(action)

func _release() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)

## One movement tick towards a point. `use_lane` also lines the player up in depth, which
## doors need and open street walking does not.
func _step_towards(target: Vector2, use_lane: bool) -> void:
	var p := player()
	if p == null or not is_instance_valid(p):
		_release()
		await frames(3)
		return
	# Anything that takes control mid-walk gets dealt with here rather than waited out. An
	# encounter's clear-dialogue fires 0.6s AFTER the fight ends, which is long after the
	# walk has resumed, so a bot that only waits for gameplay stands still forever holding
	# a dialogue box nobody is going to close.
	if not GameManager.is_gameplay_active():
		_release()
		await settle()
		return

	# Lane first when the target is a specific thing (a door, a person). Open-street walking
	# ignores depth entirely, which is what lets a detour stick.
	#
	# The target's depth is clamped into the walkable band first. Door volumes are authored
	# just outside it -- the metro door sits at y=32 where the lane starts at 34 -- so a bot
	# that steers at the raw value holds "up" against the wall forever and never advances a
	# pixel in x. It looked exactly like a locked door, and it is not one.
	var goal_y: float = target.y
	var area_now = GameManager.current_area
	if area_now != null:
		goal_y = clampf(goal_y, area_now.lane_min + 2.0, area_now.lane_max - 2.0)
	var dy: float = goal_y - p.global_position.y
	if use_lane and absf(dy) > 5.0 and _detour <= 0:
		_hold("move_down" if dy > 0.0 else "move_up")
		await frames(4)
		return

	# Stuck means "not getting closer", not "not moving". Walking into a barrel slides you
	# along it, so the position keeps changing while the gap never shrinks -- which is
	# exactly the case the first version of this missed.
	var gap: float = absf(target.x - p.global_position.x)
	if gap > _last_gap - 0.6:
		_still_ticks += 1
	else:
		_still_ticks = 0
	_last_gap = gap

	if _still_ticks > 8 and _detour <= 0:
		_detour = 12
		# Alternate, so a detour that fails is followed by one the other way rather than the
		# same one forever.
		_detour_dir = -_detour_dir
		var area = GameManager.current_area
		if area != null:
			var mid: float = (area.lane_min + area.lane_max) * 0.5
			# Never detour off the walkable band; head back towards the middle if at an edge.
			if p.global_position.y > area.lane_max - 6.0:
				_detour_dir = -1.0
			elif p.global_position.y < area.lane_min + 6.0:
				_detour_dir = 1.0
		_still_ticks = 0

	if _detour > 0:
		_detour -= 1
		# Diagonally, not sideways. A detour that stops moving forward is just a pause, and
		# the bot spends the whole street pausing.
		_release()
		Input.action_press("move_down" if _detour_dir > 0.0 else "move_up")
		var ddx: float = target.x - p.global_position.x
		if absf(ddx) > 6.0:
			Input.action_press("move_right" if ddx > 0.0 else "move_left")
		await frames(3)
		return

	var dx: float = target.x - p.global_position.x
	if absf(dx) > 6.0:
		_hold("move_right" if dx > 0.0 else "move_left")
	else:
		_release()
	await frames(4)

func _find_door_to(area_id: String) -> Node:
	var area = GameManager.current_area
	if area == null:
		return null
	for n in area.actors_root.get_children():
		if n is Door and (n as Door).to_area == area_id:
			return n
	return null

func _find_npc(npc_id: String) -> Node2D:
	var area = GameManager.current_area
	if area == null:
		return null
	for n in area.actors_root.get_children():
		if n.get("npc_id") == npc_id:
			return n
	for n in get_tree().get_nodes_in_group("interactables"):
		if n.get("npc_id") == npc_id:
			return n
	return null

## Click through whatever is on screen until the box is gone.
func _advance_dialogue() -> void:
	var guard := 0
	while DialogueManager.is_active() and guard < 900:
		if DialogueManager._box:
			DialogueManager._box._typing = false
			DialogueManager._box.line_finished.emit()
		await frames(2)
		guard += 1
	if guard >= 900:
		fail("a dialogue box in %s never closed" % GameManager.player_data.current_area)

## Wait for cutscenes, dialogue, fades and area loads to finish.
func settle() -> void:
	var guard := 0
	while guard < 1200:
		var busy := false
		# A comic panel waits for a keypress and nothing else will ever send one, so the bot
		# has to press it. Without this the run stops dead on the opening screen, and it
		# looks exactly like the game hanging.
		var comic := _find_comic()
		if comic != null:
			comic._advance()
			busy = true
		if DialogueManager.is_active():
			await _advance_dialogue()
			busy = true
		if CutsceneManager.is_playing():
			busy = true
		if SceneManager.is_busy():
			busy = true
		if not busy and GameManager.is_gameplay_active():
			return
		await frames(2)
		guard += 1

## The comic player, if one is on screen. Created on demand by CutsceneManager, so it is
## found by type rather than by a known path.
func _find_comic() -> Node:
	for n in get_tree().root.get_children():
		if n.get_script() != null and n.has_method("is_playing") and n.has_method("_advance") 				and n.get("_panels") != null and n.is_playing():
			return n
	return null

func _revive_if_dead() -> void:
	var p := player()
	if p == null or not is_instance_valid(p):
		return
	if not p.dead:
		return
	revives += 1
	if revives > MAX_REVIVES:
		fail("died %d times; the route is not survivable as played" % revives)
		return
	await seconds(2.0)
	await settle()
	var p2 := player()
	if p2 != null and is_instance_valid(p2):
		p2.hp = p2.max_hp
		p2.dead = false

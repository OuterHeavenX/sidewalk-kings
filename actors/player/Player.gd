class_name Player
extends Actor
## The player fighter. Input handling, combo routing, grabs, weapons, energy and special.

const RUN_DOUBLE_TAP_WINDOW := 0.26
const JUMP_VELOCITY := 240.0
const DASH_SPEED := 260.0
const DASH_TIME := 0.18
const GRAB_RANGE := 22.0
const GRAB_LANE := 16.0
const RESPAWN_INVULN := 1.4

@onready var combat: CombatController = $Combat
@onready var hitbox: Hitbox = $Hitbox
@onready var grab_point: Marker2D = $Visual/GrabPoint
@onready var weapon_slot: Node2D = $Visual/WeaponSlot

var energy: float = 60.0
var max_energy: float = 60.0
var special_meter: float = 0.0
var running: bool = false
var dash_time: float = 0.0
var held_weapon: Node = null
var _last_dir_tap: Dictionary = {"dir": 0, "time": 0.0}
var _jump_attacked: bool = false
var _grab_hold_frames: int = 0
var _step_timer: float = 0.0
var _energy_lock: float = 0.0
var nearby_interactable: Node = null

func _ready() -> void:
	super._ready()
	is_player = true
	team = 0
	add_to_group("player")
	combat.setup(self, hitbox)
	combat.move_hit.connect(_on_move_hit)
	sync_from_data()
	GameManager.player = self
	EventBus.player_spawned.emit(self)
	hurtbox.set_invulnerable(RESPAWN_INVULN)
	invuln_frames = int(RESPAWN_INVULN * 60)

## Pull stats from the persistent PlayerState.
func sync_from_data() -> void:
	var pd := GameManager.player_data
	max_hp = pd.get_max_hp()
	hp = clampi(pd.hp if pd.hp > 0 else max_hp, 1, max_hp)
	max_energy = pd.get_max_energy()
	energy = clampf(pd.energy if pd.energy > 0 else max_energy, 0.0, max_energy)
	special_meter = pd.special
	move_speed = pd.get_move_speed()
	run_speed = move_speed * 1.62
	EventBus.player_hp_changed.emit(hp, max_hp)
	EventBus.player_energy_changed.emit(energy, max_energy)
	EventBus.player_special_changed.emit(special_meter)

## Push runtime values back into the persistent PlayerState (called before saving).
func sync_to_data() -> void:
	var pd := GameManager.player_data
	pd.hp = hp
	pd.energy = energy
	pd.special = special_meter
	pd.equipped_weapon = held_weapon.weapon_id if is_instance_valid(held_weapon) else ""

func _physics_process(delta: float) -> void:
	if GameManager.is_frozen():
		return
	_read_input(delta)
	super._physics_process(delta)
	_regen(delta)
	_footsteps(delta)
	_update_weapon_slot()
	_scan_interactables()

## Find the closest thing the player could interact with and tell the HUD about it.
func _scan_interactables() -> void:
	var best: Node = null
	var best_d := 26.0
	for n in get_tree().get_nodes_in_group("interactables"):
		if not is_instance_valid(n) or not n.has_method("interact"):
			continue
		var d := absf(n.global_position.x - global_position.x) + absf(n.global_position.y - global_position.y) * 1.4
		if d < best_d:
			best_d = d
			best = n
	if best != nearby_interactable:
		if nearby_interactable != null:
			EventBus.interactable_unfocused.emit(nearby_interactable)
		nearby_interactable = best
		if best != null:
			EventBus.interactable_focused.emit(best)

func _read_input(delta: float) -> void:
	if not GameManager.is_gameplay_active() or dead:
		move_input = Vector2.ZERO
		running = false
		return

	var dir := InputManager.get_move_vector()
	if TouchControls.active:
		dir = TouchControls.move_vector
	if dir.length() > 1.0:
		dir = dir.normalized()

	# Double-tap to run
	if absf(dir.x) > 0.6:
		var d := signi(int(round(dir.x)))
		if d != 0 and _last_dir_tap.dir != d:
			var now := Time.get_ticks_msec() / 1000.0
			if _last_dir_tap.dir == 0:
				_last_dir_tap = {"dir": d, "time": now}
			else:
				_last_dir_tap = {"dir": d, "time": now}
	else:
		if _last_dir_tap.dir != 0:
			var now := Time.get_ticks_msec() / 1000.0
			if now - float(_last_dir_tap.time) > RUN_DOUBLE_TAP_WINDOW:
				_last_dir_tap.dir = 0

	running = Input.is_action_pressed("sprint") or TouchControls.sprinting
	if dash_time > 0.0:
		dash_time -= delta

	if state == State.GRABBED:
		move_input = Vector2.ZERO
		_struggle()
		return

	if can_move():
		move_input = dir
		if dir.x != 0.0 and combat.current == null:
			facing = 1 if dir.x > 0 else -1
	else:
		move_input = Vector2.ZERO

	# --- Action inputs ---
	if Input.is_action_just_pressed("attack_light"):
		_press_attack(MoveData.InputKind.LIGHT)
	if Input.is_action_just_pressed("attack_heavy"):
		_press_attack(MoveData.InputKind.HEAVY)
	if Input.is_action_just_pressed("special"):
		_press_special()
	if Input.is_action_just_pressed("jump"):
		_press_jump()
	if Input.is_action_just_pressed("grab"):
		_press_grab()

	# Animation state while free
	if combat.current == null and state in [State.IDLE, State.WALK, State.RUN]:
		if z_height > 0.0:
			play_anim("jump")
		elif move_input.length() > 0.1:
			if running:
				set_state(State.RUN)
				play_anim("run" if held_weapon == null else "weapon_idle")
			else:
				set_state(State.WALK)
				play_anim("walk" if held_weapon == null else "weapon_idle")
		else:
			set_state(State.IDLE)
			play_anim("idle" if held_weapon == null else "weapon_idle")

func get_current_speed() -> float:
	if dash_time > 0.0:
		return DASH_SPEED
	if z_height > 0.0:
		return move_speed * 0.92
	return run_speed if running else move_speed

# ---------------- Attacks ----------------
func _press_attack(kind: int) -> void:
	if dead:
		return
	# Grab follow-ups
	if state == State.GRABBING and is_instance_valid(grabbing):
		_grab_attack(kind)
		return
	# Air attack
	if z_height > 12.0 and not _jump_attacked:
		var air_id := "jump_kick" if kind == MoveData.InputKind.LIGHT else "jump_stomp"
		var air := _get_move(air_id)
		if air == null:
			air = _get_move("jump_kick")
		if air and _start(air):
			_jump_attacked = true
		return
	if not (can_act() or combat.can_cancel()):
		combat.buffer("light" if kind == MoveData.InputKind.LIGHT else "heavy")
		return
	# Combo follow-up
	if combat.current != null and combat.can_cancel():
		var nxt := combat.find_followup(kind)
		if nxt:
			combat.cancel()
			_start(nxt)
			return
	# Weapon attack takes priority when carrying something
	if is_instance_valid(held_weapon):
		if kind == MoveData.InputKind.HEAVY:
			_throw_weapon()
		else:
			_start_weapon()
		return
	# Running attack
	if (running or dash_time > 0.0) and move_input.length() > 0.2:
		var rm := _get_move("run_attack")
		if rm and _start(rm):
			return
	var starter := _get_move("punch_1" if kind == MoveData.InputKind.LIGHT else "heavy")
	if starter:
		_start(starter)

func _press_special() -> void:
	if dead or not can_act():
		return
	var m := _get_move("special_burst")
	if m == null:
		return
	if special_meter < 100.0:
		GameManager.notify("Special not ready", "deny")
		AudioManager.play_ui("menu_deny")
		return
	if _start(m):
		special_meter = 0.0
		EventBus.player_special_changed.emit(special_meter)
		AudioManager.play_sfx("special_charge", -2.0)
		hurtbox.set_invulnerable(0.5)
		invuln_frames = 30

func _press_jump() -> void:
	if dead:
		return
	if state == State.GRABBING and is_instance_valid(grabbing):
		_throw_grabbed(Vector2(facing, 0))
		return
	if z_height <= 0.0 and can_act():
		z_velocity = JUMP_VELOCITY
		_jump_attacked = false
		set_state(State.JUMP)
		play_anim("jump", true, true)
		AudioManager.play_sfx("jump", -8.0)
		FX.dust(global_position, get_parent())

func _press_grab() -> void:
	if dead:
		return
	if state == State.GRABBING and is_instance_valid(grabbing):
		_throw_grabbed(Vector2(facing, 0))
		return
	# Interact first (NPCs, doors, props)
	if nearby_interactable and is_instance_valid(nearby_interactable) and nearby_interactable.has_method("interact"):
		nearby_interactable.interact(self)
		return
	# Pick up a weapon
	var w := _find_weapon_in_range()
	if w:
		pick_up_weapon(w)
		return
	if is_instance_valid(held_weapon):
		drop_weapon()
		return
	if not can_act():
		return
	# Grab an enemy
	var target := _find_grab_target()
	if target:
		if try_grab(target):
			play_anim("grab", false, true)
			AudioManager.play_sfx("grab", -4.0)
			_grab_hold_frames = 0
		return
	var gm := _get_move("grab_whiff")
	if gm:
		_start(gm)

func _start(m: MoveData) -> bool:
	if m == null:
		return false
	if m.energy_cost > 0.0:
		if energy < m.energy_cost:
			AudioManager.play_ui("menu_deny")
			return false
		energy -= m.energy_cost
		_energy_lock = 0.55
		EventBus.player_energy_changed.emit(energy, max_energy)
	set_state(State.ATTACK)
	return combat.start_move(m, _damage_multiplier(m))

## Weapon swings use the weapon's own damage value, scaled by weapon skill.
func _start_weapon() -> bool:
	if not is_instance_valid(held_weapon):
		return false
	var wm: MoveData = ContentDB.get_move(held_weapon.data.swing_move)
	if wm == null:
		wm = ContentDB.get_move("weapon_swing")
	if wm == null:
		return false
	var mult := float(held_weapon.data.damage) / float(maxi(1, wm.damage)) * GameManager.player_data.get_weapon_multiplier()
	set_state(State.ATTACK)
	AudioManager.play_sfx(held_weapon.data.swing_sound, -6.0)
	return combat.start_move(wm, mult)

## Weapons wear out as they land hits.
func _on_move_hit(_target: Node, move: MoveData) -> void:
	if move != null and move.damage_kind == MoveData.DamageKind.WEAPON and is_instance_valid(held_weapon):
		held_weapon.register_swing_hit()

func _damage_multiplier(m: MoveData) -> float:
	var pd := GameManager.player_data
	match m.damage_kind:
		MoveData.DamageKind.PUNCH: return pd.get_punch_multiplier()
		MoveData.DamageKind.KICK: return pd.get_kick_multiplier()
		MoveData.DamageKind.THROW: return pd.get_throw_multiplier()
		MoveData.DamageKind.WEAPON: return pd.get_weapon_multiplier()
		MoveData.DamageKind.SPECIAL: return pd.get_special_multiplier()
	return 1.0

func _get_move(id: String) -> MoveData:
	if not GameManager.has_move(id):
		return null
	return ContentDB.get_move(id)

# ---------------- Grab / throw ----------------
func _find_grab_target() -> Actor:
	var best: Actor = null
	var best_d := 1e9
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Actor) or e.dead or not e.can_be_grabbed:
			continue
		var dx: float = e.global_position.x - global_position.x
		if signf(dx) != float(facing) and absf(dx) > 6.0:
			continue
		if absf(dx) > GRAB_RANGE or lane_distance_to(e) > GRAB_LANE:
			continue
		if absf(e.z_height - z_height) > 26.0:
			continue
		var d: float = absf(dx) + lane_distance_to(e) * 0.5
		if d < best_d:
			best_d = d
			best = e
	return best

func _grab_attack(kind: int) -> void:
	var mid := "grab_punch" if kind == MoveData.InputKind.LIGHT else "throw"
	if kind == MoveData.InputKind.HEAVY:
		_throw_grabbed(Vector2(facing, 0))
		return
	var m := _get_move(mid)
	if m == null:
		return
	var target: Actor = grabbing
	if not is_instance_valid(target):
		release_grab()
		return
	# Direct hit, no hitbox needed: the target is already held.
	var dmg := DamageData.from_move(m, self, facing, _damage_multiplier(m))
	dmg.knockback = Vector2.ZERO
	play_anim("grab_punch", true, true)
	AudioManager.play_sfx(m.sound, -3.0)
	target.take_damage(dmg)
	FX.spawn(m.hit_fx, target.global_position + Vector2(0, -target.z_height - 22), get_parent())
	EventBus.hit_stop.emit(m.hit_pause)
	EventBus.screen_shake.emit(m.screen_shake, 0.14)
	_grab_hold_frames += 1
	if _grab_hold_frames >= 3 or (is_instance_valid(target) and target.dead):
		release_grab()

func _throw_grabbed(dir: Vector2) -> void:
	var target: Actor = grabbing
	if not is_instance_valid(target):
		release_grab()
		return
	var m := _get_move("throw")
	if m == null:
		release_grab()
		return
	var dmg := DamageData.from_move(m, self, facing, _damage_multiplier(m))
	dmg.knockdown = true
	dmg.from_throw = true
	play_anim("throw", true, true)
	AudioManager.play_sfx("throw", -2.0)
	release_grab()
	target.grabbed_by = null
	target.take_damage(dmg)
	if is_instance_valid(target):
		target.knockback_velocity = Vector2(m.knockback.x * facing * 1.5, 0)
		target.z_velocity = 210.0
		target.set_thrown(self)
	EventBus.screen_shake.emit(3.0, 0.2)
	EventBus.hit_stop.emit(0.06)

func _struggle() -> void:
	if Input.is_action_just_pressed("attack_light") or Input.is_action_just_pressed("attack_heavy"):
		if is_instance_valid(grabbed_by) and grabbed_by.has_method("release_grab"):
			grabbed_by.release_grab()
			grabbed_by = null
			set_state(State.IDLE)

# ---------------- Weapons ----------------
func _find_weapon_in_range() -> Node:
	if is_instance_valid(held_weapon):
		return null
	var best: Node = null
	var best_d := 26.0
	for w in get_tree().get_nodes_in_group("weapons"):
		if not is_instance_valid(w) or w.held_by != null or w.thrown:
			continue
		var d := global_position.distance_to(w.global_position)
		if d < best_d:
			best_d = d
			best = w
	return best

func pick_up_weapon(w: Node) -> void:
	if is_instance_valid(held_weapon):
		drop_weapon()
	held_weapon = w
	w.pick_up(self)
	play_anim("pickup", true, true)
	AudioManager.play_sfx("weapon_pickup", -5.0)
	GameManager.player_data.equipped_weapon = w.weapon_id

func drop_weapon() -> void:
	if not is_instance_valid(held_weapon):
		held_weapon = null
		return
	held_weapon.drop()
	held_weapon = null
	GameManager.player_data.equipped_weapon = ""

func _throw_weapon() -> void:
	if not is_instance_valid(held_weapon):
		return
	var w := held_weapon
	held_weapon = null
	GameManager.player_data.equipped_weapon = ""
	play_anim("throw_item", true, true)
	AudioManager.play_sfx("throw", -4.0)
	w.throw_forward(self, facing)

func _update_weapon_slot() -> void:
	if is_instance_valid(held_weapon) and weapon_slot:
		held_weapon.global_position = weapon_slot.global_position
		held_weapon.scale.x = absf(held_weapon.scale.x) * facing

## Give a weapon by id (used by the weapon shop). Returns false if it couldn't spawn.
func give_weapon(weapon_id: String) -> bool:
	var data: WeaponData = ContentDB.get_weapon(weapon_id)
	if data == null:
		return false
	var scene: PackedScene = load("res://weapons/Weapon.tscn")
	var w = scene.instantiate()
	w.weapon_id = weapon_id
	get_parent().add_child(w)
	w.global_position = global_position
	pick_up_weapon(w)
	return true

# ---------------- Vitals ----------------
func _regen(delta: float) -> void:
	if _energy_lock > 0.0:
		_energy_lock -= delta
		return
	if energy < max_energy:
		energy = minf(max_energy, energy + GameManager.player_data.get_energy_regen() * delta)
		EventBus.player_energy_changed.emit(energy, max_energy)

func restore_energy(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, max_energy)
	EventBus.player_energy_changed.emit(energy, max_energy)

func add_special(amount: float) -> void:
	special_meter = clampf(special_meter + amount, 0.0, 100.0)
	EventBus.player_special_changed.emit(special_meter)

func compute_damage(d: DamageData) -> int:
	var reduced := float(d.amount) * GameManager.player_data.get_defense_reduction()
	return maxi(1, int(round(reduced)))

func on_damaged(d: DamageData, amount: int) -> void:
	GameManager.player_data.hp = hp
	EventBus.player_hp_changed.emit(hp, max_hp)
	AudioManager.play_sfx("hurt", -3.0)
	EventBus.screen_shake.emit(2.0, 0.15)
	add_special(4.0)
	FX.number(str(amount), global_position + Vector2(0, -z_height - 34), Color(1, 0.5, 0.5), get_parent())
	invuln_frames = 26
	hurtbox.set_invulnerable(0.42)

func heal(amount: int) -> void:
	hp = clampi(hp + amount, 0, max_hp)
	GameManager.player_data.hp = hp
	EventBus.player_hp_changed.emit(hp, max_hp)
	FX.number("+" + str(amount), global_position + Vector2(0, -z_height - 34), Color(0.5, 1, 0.6), get_parent())

func die(d: DamageData = null) -> void:
	if dead:
		return
	super.die(d)
	GameManager.player_data.hp = 0
	EventBus.player_hp_changed.emit(0, max_hp)
	EventBus.player_died.emit()
	drop_weapon()

func _on_landed(hard: bool) -> void:
	_jump_attacked = false
	if state == State.JUMP:
		set_state(State.IDLE)
	if hard:
		AudioManager.play_sfx("land", -12.0)
		FX.dust(global_position, get_parent())

func _footsteps(delta: float) -> void:
	if z_height > 0.0 or move_input.length() < 0.2 or not can_move():
		return
	_step_timer -= delta * (1.6 if running else 1.0)
	if _step_timer <= 0.0:
		_step_timer = 0.34
		AudioManager.play_sfx("step", -20.0, 0.15)
		if running:
			FX.dust(global_position + Vector2(-facing * 6, 0), get_parent())

func on_enemy_defeated_reward(xp: int, money: int) -> void:
	add_special(8.0)

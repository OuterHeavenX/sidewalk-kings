class_name EnemyBase
extends Actor
## Every enemy in the game is this script plus an EnemyData resource.
##
## The AI keeps a preferred fighting distance, circles, repositions in the lane and
## waits out cooldowns, so a group surrounds the player instead of stacking on one pixel.

enum AI { WAIT, APPROACH, CIRCLE, ATTACK, RETREAT, RECOVER, SEEK_WEAPON, STUNNED_STATE }

@onready var combat: CombatController = $Combat
@onready var hitbox: Hitbox = $Hitbox
@onready var health_bar: Node2D = $HealthBar
@onready var alert: Sprite2D = $Alert

var enemy_id: String = ""
var data: EnemyData = null
var gang_id: String = ""
var ai_state: AI = AI.WAIT
var target: Node2D = null
var think_timer: float = 0.0
var attack_cooldown: float = 0.0
var circle_dir: int = 1
var desired_lane_offset: float = 0.0
var slot_index: int = 0
var aggro: bool = false
var held_weapon: Node = null
var level_scale: float = 1.0
var thrown_by: Node = null
var thrown_frames: int = 0
var _stagger_frames: int = 0
var _spawn_grace: float = 0.35
var _knockdown_timer: float = 0.0
var _taunted: bool = false

func _ready() -> void:
	super._ready()
	team = 1
	add_to_group("enemies")
	combat.setup(self, hitbox)
	combat.move_hit.connect(func(_t, m):
		if m != null and m.damage_kind == MoveData.DamageKind.WEAPON and is_instance_valid(held_weapon):
			held_weapon.register_swing_hit())
	if data:
		apply_data(data)
	_pick_lane_offset()

func apply_data(d: EnemyData) -> void:
	data = d
	enemy_id = d.id
	gang_id = d.gang
	max_hp = maxi(1, int(d.max_hp * level_scale))
	hp = max_hp
	move_speed = d.move_speed
	run_speed = d.run_speed
	weight = d.weight
	armor_threshold = d.armor_threshold
	can_be_grabbed = d.can_be_grabbed
	circle_dir = 1 if randf() < 0.5 else -1
	if d.sprite_frames and sprite:
		sprite.sprite_frames = d.sprite_frames
	if sprite:
		sprite.modulate = d.tint
		sprite.scale = Vector2(d.scale, d.scale)
	if health_bar:
		health_bar.visible = false
		health_bar.set_max(max_hp)
	play_anim("idle")

func _pick_lane_offset() -> void:
	desired_lane_offset = randf_range(-8.0, 8.0)

func _physics_process(delta: float) -> void:
	if GameManager.is_frozen():
		return
	if _spawn_grace > 0.0:
		_spawn_grace -= delta
	_update_ai(delta)
	super._physics_process(delta)
	_update_thrown()
	_update_health_bar()
	_separate()

# ---------------- AI ----------------
func _update_ai(delta: float) -> void:
	if dead or data == null:
		move_input = Vector2.ZERO
		return
	if attack_cooldown > 0.0:
		attack_cooldown -= delta
	if state == State.KNOCKDOWN:
		_handle_knockdown(delta)
		return
	if state in [State.HURT, State.GRABBED, State.GETUP, State.ATTACK, State.DEFEATED]:
		move_input = Vector2.ZERO
		return
	if not GameManager.is_gameplay_active():
		move_input = Vector2.ZERO
		play_anim("idle")
		return

	target = _acquire_target()
	if target == null:
		move_input = Vector2.ZERO
		play_anim("idle")
		return

	think_timer -= delta
	if think_timer <= 0.0:
		_decide()

	var to_target: Vector2 = target.global_position - global_position
	var dist := absf(to_target.x)
	var lane_diff: float = target.global_position.y + desired_lane_offset - global_position.y
	if absf(to_target.x) > 4.0:
		facing = 1 if to_target.x > 0 else -1

	match ai_state:
		AI.WAIT:
			move_input = Vector2.ZERO
			play_anim("idle")
		AI.APPROACH:
			var want: float = data.preferred_distance
			var mx: float = 0.0
			if dist > want + 4.0:
				mx = signf(to_target.x)
			elif dist < want - 8.0:
				mx = -signf(to_target.x)
			var my := clampf(lane_diff / 14.0, -1.0, 1.0)
			move_input = Vector2(mx, my)
			var moving := move_input.length() > 0.1
			play_anim("run" if (moving and data.archetype == EnemyData.Archetype.RUSHER) else ("walk" if moving else "idle"))
		AI.CIRCLE:
			move_input = Vector2(0.0, float(circle_dir) * 0.85)
			if dist > data.preferred_distance * 2.2:
				move_input.x = signf(to_target.x) * 0.5
			play_anim("walk")
		AI.RETREAT:
			move_input = Vector2(-signf(to_target.x) * 0.9, clampf(lane_diff / 20.0, -0.6, 0.6))
			play_anim("walk")
		AI.SEEK_WEAPON:
			var w := _nearest_free_weapon()
			if w == null:
				ai_state = AI.APPROACH
			else:
				var d2: Vector2 = w.global_position - global_position
				move_input = Vector2(signf(d2.x), clampf(d2.y / 12.0, -1.0, 1.0))
				play_anim("walk")
				if d2.length() < 16.0:
					_grab_weapon(w)
		AI.ATTACK:
			move_input = Vector2.ZERO
		AI.RECOVER:
			move_input = Vector2.ZERO
			play_anim("idle")

func _decide() -> void:
	think_timer = data.reaction_delay * randf_range(0.7, 1.4)
	if target == null:
		return
	var to_target: Vector2 = target.global_position - global_position
	var dist := absf(to_target.x)
	# to_target is already a delta; lane distance is just its y component.
	var lane_diff := absf(to_target.y)
	if not aggro:
		if dist < 190.0:
			_become_aggro()
		else:
			ai_state = AI.WAIT
			return

	# Weapon users go and fetch one when unarmed.
	if data.picks_up_weapons and held_weapon == null and randf() < 0.5:
		if _nearest_free_weapon() != null:
			ai_state = AI.SEEK_WEAPON
			return

	# Ranged archetype prefers to keep distance and throw.
	if data.archetype == EnemyData.Archetype.RANGED:
		if dist < data.preferred_distance * 0.7:
			ai_state = AI.RETREAT
			return
		if dist < data.ranged_distance and lane_diff < 28.0 and attack_cooldown <= 0.0 and randf() < data.aggression + 0.2:
			_do_ranged()
			return
		ai_state = AI.APPROACH if dist > data.ranged_distance else AI.CIRCLE
		return

	var in_range := dist <= data.preferred_distance + 8.0 and lane_diff <= 16.0
	if in_range and attack_cooldown <= 0.0:
		if randf() < data.aggression:
			_do_attack(dist)
			return
		ai_state = AI.CIRCLE if randf() < data.circle_chance else AI.WAIT
		return
	if in_range:
		ai_state = AI.CIRCLE if randf() < data.circle_chance else AI.WAIT
		if randf() < 0.35:
			circle_dir = -circle_dir
		return
	ai_state = AI.APPROACH

func _become_aggro() -> void:
	if aggro:
		return
	aggro = true
	if alert:
		alert.visible = true
		var tw := create_tween()
		tw.tween_property(alert, "position:y", alert.position.y - 5.0, 0.14)
		tw.tween_property(alert, "position:y", alert.position.y, 0.1)
		tw.tween_interval(0.5)
		tw.tween_callback(func(): if is_instance_valid(alert): alert.visible = false)
	if not _taunted and data.taunts.size() > 0 and randf() < 0.28:
		_taunted = true
		FX.number(data.taunts[randi() % data.taunts.size()], global_position + Vector2(0, -46), Color(1, 0.9, 0.7), get_parent())

func _do_attack(dist: float) -> void:
	if data.moves.is_empty():
		return
	var mid: String = data.moves[randi() % data.moves.size()]
	# Grapplers try to grab when close enough
	if data.archetype == EnemyData.Archetype.GRAPPLER and dist < 22.0 and randf() < 0.55:
		if _try_enemy_grab():
			return
	if data.heavy_move != "" and randf() < 0.3:
		mid = data.heavy_move
	if held_weapon != null and is_instance_valid(held_weapon):
		mid = held_weapon.data.swing_move
	var m: MoveData = ContentDB.get_move(mid)
	if m == null:
		return
	ai_state = AI.ATTACK
	set_state(State.ATTACK)
	attack_cooldown = data.attack_cooldown * randf_range(0.8, 1.25)
	combat.start_move(m, data.damage_multiplier * level_scale)

func _do_ranged() -> void:
	var mid := data.ranged_move if data.ranged_move != "" else "enemy_throw_rock"
	var m: MoveData = ContentDB.get_move(mid)
	if m == null:
		return
	ai_state = AI.ATTACK
	set_state(State.ATTACK)
	attack_cooldown = data.attack_cooldown * randf_range(1.0, 1.4)
	play_anim("throw_item", true, true)
	AudioManager.play_sfx("throw", -8.0)
	var proj_scene: PackedScene = load("res://weapons/Projectile.tscn")
	var p = proj_scene.instantiate()
	get_parent().add_child(p)
	p.launch(self, Vector2(facing, 0), m, data.damage_multiplier * level_scale)
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(self) and state == State.ATTACK:
		set_state(State.IDLE)
		ai_state = AI.RETREAT

func _try_enemy_grab() -> bool:
	if target == null or not (target is Actor):
		return false
	var t: Actor = target
	if absf(t.global_position.x - global_position.x) > 24.0 or lane_distance_to(t) > 16.0:
		return false
	if t.z_height > 14.0:
		return false
	if try_grab(t):
		play_anim("grab", false, true)
		AudioManager.play_sfx("grab", -6.0)
		attack_cooldown = data.attack_cooldown * 1.6
		_enemy_grab_sequence()
		return true
	return false

func _enemy_grab_sequence() -> void:
	# Hold briefly, land one hit, then shove the player away.
	await get_tree().create_timer(0.45).timeout
	if not is_instance_valid(self) or grabbing == null or not is_instance_valid(grabbing) or dead:
		release_grab()
		return
	var m: MoveData = ContentDB.get_move("enemy_grab_hit")
	if m:
		var dmg := DamageData.from_move(m, self, facing, data.damage_multiplier * level_scale)
		dmg.knockdown = true
		play_anim("throw", true, true)
		var t: Actor = grabbing
		release_grab()
		t.grabbed_by = null
		t.take_damage(dmg)
		AudioManager.play_sfx("throw", -4.0)
	else:
		release_grab()

func _acquire_target() -> Node2D:
	var p := GameManager.player
	if is_instance_valid(p) and not p.dead:
		return p
	return null

func _nearest_free_weapon() -> Node:
	var best: Node = null
	var best_d := 150.0
	for w in get_tree().get_nodes_in_group("weapons"):
		if not is_instance_valid(w) or w.held_by != null or w.thrown:
			continue
		var d := global_position.distance_to(w.global_position)
		if d < best_d:
			best_d = d
			best = w
	return best

func _grab_weapon(w: Node) -> void:
	held_weapon = w
	w.pick_up(self)
	ai_state = AI.APPROACH
	AudioManager.play_sfx("weapon_pickup", -12.0)

func _update_thrown() -> void:
	if thrown_frames > 0:
		thrown_frames -= 1
		# A thrown body knocks over whatever it crashes into.
		for node in get_tree().get_nodes_in_group("enemies"):
			var e := node as Actor
			if e == null or e == self or not is_instance_valid(e) or e.dead:
				continue
			if global_position.distance_to(e.global_position) < 16.0 and absf(e.z_height - z_height) < 24.0:
				var m: MoveData = ContentDB.get_move("body_collide")
				if m:
					var dmg := DamageData.from_move(m, thrown_by, facing, 1.0)
					dmg.knockdown = true
					e.take_damage(dmg)
				thrown_frames = 0
				break
	if is_instance_valid(held_weapon):
		held_weapon.global_position = global_position + Vector2(facing * 10, -z_height - 20)
		held_weapon.scale.x = absf(held_weapon.scale.x) * facing

func set_thrown(by: Node) -> void:
	thrown_by = by
	thrown_frames = 40

func _handle_knockdown(delta: float) -> void:
	move_input = Vector2.ZERO
	if z_height > 0.0:
		return
	_knockdown_timer += delta
	if _knockdown_timer < 0.75:
		play_anim("lying", true, true)
		return
	_knockdown_timer = 0.0
	set_state(State.GETUP)
	play_anim("getup", true, true)
	invuln_frames = 20
	await get_tree().create_timer(0.34).timeout
	if is_instance_valid(self) and not dead and state == State.GETUP:
		set_state(State.IDLE)
		ai_state = AI.RETREAT
		think_timer = 0.2
		attack_cooldown = maxf(attack_cooldown, 0.4)

func _on_landed(hard: bool) -> void:
	if state == State.KNOCKDOWN and hard:
		AudioManager.play_sfx("land", -10.0)
		FX.dust(global_position, get_parent())
		EventBus.screen_shake.emit(1.4, 0.1)
	elif state == State.JUMP:
		set_state(State.IDLE)

# ---------------- Damage / rewards ----------------
func compute_damage(d: DamageData) -> int:
	var amount := float(d.amount) - data.defense if data else float(d.amount)
	return maxi(1, int(round(amount)))

func on_damaged(d: DamageData, amount: int) -> void:
	_become_aggro()
	if health_bar and data and data.show_health_bar:
		health_bar.visible = true
		health_bar.set_value(hp)
	AudioManager.play_sfx("enemy_hurt", -8.0)
	FX.number(str(amount), global_position + Vector2(0, -z_height - 36),
		Color(1, 0.86, 0.4) if not d.crit else Color(1, 0.5, 0.3), get_parent(), d.crit)
	if d.source and d.source.has_method("add_special"):
		d.source.add_special(2.4 if not d.heavy else 4.0)
	# Being hit interrupts the current attack unless armored
	if combat.current != null and not (armor_threshold > 0 and amount < armor_threshold):
		combat.cancel()
	think_timer = maxf(think_timer, 0.12)

func die(d: DamageData = null) -> void:
	if dead:
		return
	super.die(d)
	if health_bar:
		health_bar.visible = false
	if is_instance_valid(held_weapon):
		held_weapon.drop()
		held_weapon = null
	AudioManager.play_sfx("enemy_defeat", -4.0)
	FX.stars(global_position + Vector2(0, -30), get_parent(), 4)
	_grant_rewards()
	if data and data.defeat_lines.size() > 0 and randf() < 0.4:
		FX.number(data.defeat_lines[randi() % data.defeat_lines.size()],
			global_position + Vector2(0, -40), Color(0.9, 0.9, 1.0), get_parent())
	EventBus.enemy_defeated.emit(self, enemy_id)
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	hurtbox.active = false
	# Sink and vanish
	await get_tree().create_timer(1.1).timeout
	if not is_instance_valid(self):
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.tween_callback(queue_free)

func _grant_rewards() -> void:
	if data == null:
		return
	var pd := GameManager.player_data
	var money := int(randi_range(data.money_min, data.money_max) * pd.get_luck_money_multiplier() * level_scale)
	var xp := int(data.xp * level_scale)
	GameManager.add_xp(xp)
	FX.number("+%d XP" % xp, global_position + Vector2(10, -50), Color(0.6, 0.85, 1.0), get_parent())
	_drop_money(money)
	if data.drop_table.size() > 0 and randf() < data.drop_chance:
		_drop_item(data.drop_table[randi() % data.drop_table.size()])
	if is_instance_valid(GameManager.player) and GameManager.player.has_method("on_enemy_defeated_reward"):
		GameManager.player.on_enemy_defeated_reward(xp, money)

func _drop_money(total: int) -> void:
	if total <= 0:
		return
	var scene: PackedScene = load("res://world/props/MoneyPickup.tscn")
	var coins := clampi(int(ceil(total / 6.0)), 1, 6)
	var per := maxi(1, int(round(float(total) / coins)))
	for i in coins:
		var c = scene.instantiate()
		get_parent().add_child(c)
		c.setup(per, global_position + Vector2(randf_range(-6, 6), 0), Vector2(randf_range(-40, 40), 0), randf_range(80.0, 150.0))

func _drop_item(item_id: String) -> void:
	var scene: PackedScene = load("res://world/props/ItemPickup.tscn")
	var p = scene.instantiate()
	get_parent().add_child(p)
	p.setup(item_id, global_position, Vector2(randf_range(-30, 30), 0), 120.0)

func _update_health_bar() -> void:
	if health_bar and health_bar.visible:
		health_bar.set_value(hp)

## Push apart from other enemies so a crowd spreads out instead of stacking.
func _separate() -> void:
	if dead:
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Actor
		if e == null or e == self or not is_instance_valid(e) or e.dead:
			continue
		var diff: Vector2 = global_position - e.global_position
		var dist: float = diff.length()
		if dist < 0.01:
			diff = Vector2(randf_range(-1, 1), randf_range(-1, 1))
			dist = 1.0
		var min_dist: float = body_radius + e.body_radius
		if dist < min_dist:
			var push: Vector2 = diff.normalized() * (min_dist - dist) * 0.5
			position += Vector2(push.x * 0.5, push.y)

class_name Boss
extends EnemyBase
## Boss fighter: intro, two phases, telegraphed heavy move, dedicated health bar and music.
##
## Phase 2 (below the phase threshold) speeds the boss up, shortens cooldowns and unlocks
## a rushing follow-up, so the fight changes shape rather than just lasting longer.

@export var boss_id: String = "big_starch"
@export var phase2_threshold: float = 0.5
@export var telegraph_move: String = "boss_slam"
@export var phase2_move: String = "boss_rush"
@export var intro_dialogue: String = ""
@export var victory_dialogue: String = ""
@export var boss_music: String = "boss"
@export var reward_money: int = 220
@export var reward_xp: int = 160
@export var reward_flag: String = "boss_starch_defeated"

var phase: int = 1
var intro_done: bool = false
var telegraphing: bool = false
var _telegraph_cooldown: float = 4.0
var _rage_timer: float = 0.0

func _ready() -> void:
	super._ready()
	add_to_group("bosses")
	can_be_grabbed = false      # must be stunned first; see _on_stunned
	if health_bar:
		health_bar.visible = false

func start_fight() -> void:
	if intro_done:
		return
	intro_done = true
	aggro = true
	EventBus.boss_started.emit(self)
	EventBus.boss_hp_changed.emit(hp, max_hp)
	AudioManager.play_sfx("boss_warning", -2.0)
	AudioManager.play_music(boss_music)

func _update_ai(delta: float) -> void:
	if not intro_done:
		move_input = Vector2.ZERO
		play_anim("idle")
		return
	if _telegraph_cooldown > 0.0:
		_telegraph_cooldown -= delta
	if phase == 2:
		_rage_timer -= delta
	super._update_ai(delta)

func _decide() -> void:
	if target == null or telegraphing:
		return
	var dist := absf(target.global_position.x - global_position.x)
	var lane_diff := absf(target.global_position.y - global_position.y)
	think_timer = data.reaction_delay * (0.6 if phase == 2 else 1.0) * randf_range(0.7, 1.2)

	# Signature telegraphed slam: slow wind-up the player can read and punish.
	if _telegraph_cooldown <= 0.0 and dist < 76.0 and lane_diff < 26.0 and attack_cooldown <= 0.0:
		_do_telegraph()
		return
	# Phase 2 charge from range
	if phase == 2 and _rage_timer <= 0.0 and dist > 70.0 and dist < 210.0 and attack_cooldown <= 0.0:
		_do_rush()
		return
	super._decide()

func _do_telegraph() -> void:
	var m: MoveData = ContentDB.get_move(telegraph_move)
	if m == null:
		return
	telegraphing = true
	ai_state = AI.ATTACK
	set_state(State.ATTACK)
	attack_cooldown = data.attack_cooldown * 1.5
	_telegraph_cooldown = 6.5 if phase == 1 else 4.2
	# Wind-up flash so the tell is unmistakable.
	if sprite:
		var tw := create_tween()
		tw.set_loops(3)
		tw.tween_property(sprite, "modulate", Color(1.8, 1.2, 1.2), 0.1)
		tw.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)
	play_anim("taunt", true, true)
	AudioManager.play_sfx("special_charge", -6.0)
	await get_tree().create_timer(0.62).timeout
	if not is_instance_valid(self) or dead:
		telegraphing = false
		return
	telegraphing = false
	combat.start_move(m, data.damage_multiplier * level_scale)
	EventBus.screen_shake.emit(3.0, 0.25)

func _do_rush() -> void:
	var m: MoveData = ContentDB.get_move(phase2_move)
	if m == null:
		return
	ai_state = AI.ATTACK
	set_state(State.ATTACK)
	attack_cooldown = data.attack_cooldown
	_rage_timer = 3.4
	combat.start_move(m, data.damage_multiplier * level_scale)

func on_damaged(d: DamageData, amount: int) -> void:
	super.on_damaged(d, amount)
	EventBus.boss_hp_changed.emit(hp, max_hp)
	if phase == 1 and float(hp) / float(max_hp) <= phase2_threshold:
		_enter_phase_2()

func _enter_phase_2() -> void:
	phase = 2
	EventBus.boss_phase_changed.emit(2)
	EventBus.screen_shake.emit(5.0, 0.5)
	EventBus.slow_motion.emit(0.35, 0.45)
	AudioManager.play_sfx("boss_warning", -3.0)
	move_speed *= 1.3
	run_speed *= 1.3
	data = data.duplicate()
	data.attack_cooldown *= 0.62
	data.aggression = minf(1.0, data.aggression + 0.28)
	data.preferred_distance *= 0.9
	can_be_grabbed = true       # tired boss can finally be thrown
	invuln_frames = 40
	if sprite:
		var tw := create_tween()
		tw.set_loops(5)
		tw.tween_property(sprite, "modulate", Color(1.6, 0.9, 0.9), 0.08)
		tw.tween_property(sprite, "modulate", Color(1, 1, 1), 0.08)
	GameManager.notify("%s is getting serious!" % data.display_name, "boss")

func die(d: DamageData = null) -> void:
	if dead:
		return
	EventBus.slow_motion.emit(0.22, 1.1)
	EventBus.screen_shake.emit(6.0, 0.6)
	super.die(d)
	if not (boss_id in GameManager.player_data.bosses_defeated):
		GameManager.player_data.bosses_defeated.append(boss_id)
	GameManager.add_money(reward_money)
	GameManager.add_xp(reward_xp)
	if reward_flag != "":
		GameManager.set_flag(reward_flag, true)
	EventBus.boss_defeated.emit(self, boss_id)
	AudioManager.play_music("victory", 0.4)
	if victory_dialogue != "":
		await get_tree().create_timer(1.6).timeout
		if is_instance_valid(self):
			DialogueManager.start(victory_dialogue)

func _grant_rewards() -> void:
	# Bosses pay out through die(); skip the normal drop table but still shower money.
	var scene: PackedScene = load("res://world/props/MoneyPickup.tscn")
	for i in 8:
		var c = scene.instantiate()
		get_parent().add_child(c)
		c.setup(12, global_position + Vector2(randf_range(-10, 10), 0), Vector2(randf_range(-70, 70), 0), randf_range(120.0, 200.0))

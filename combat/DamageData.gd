class_name DamageData
extends RefCounted
## A single instance of damage travelling from a hitbox to a hurtbox.

var amount: int = 1
var source: Node = null
var move: MoveData = null
var direction: int = 1            # +1 facing right, -1 facing left
var knockback: Vector2 = Vector2(60, 0)
var launch: float = 0.0
var hitstun: int = 12
var knockdown: bool = false
var heavy: bool = false
var crit: bool = false
var kind: int = MoveData.DamageKind.PUNCH
var hit_sound: String = "hit_light"
var hit_fx: String = "spark_small"
var hit_pause: float = 0.04
var screen_shake: float = 0.0
var grab: bool = false
var ignore_armor: bool = false
var from_weapon: bool = false
var from_throw: bool = false

static func from_move(m: MoveData, src: Node, facing: int, multiplier: float = 1.0) -> DamageData:
	var d := DamageData.new()
	d.move = m
	d.source = src
	d.direction = facing
	d.amount = maxi(1, int(round(m.damage * multiplier)))
	d.knockback = m.knockback
	d.launch = m.launch_force
	d.hitstun = m.hitstun
	d.knockdown = m.knockdown
	d.heavy = m.is_heavy()
	d.kind = m.damage_kind
	d.hit_sound = m.hit_sound
	d.hit_fx = m.hit_fx
	d.hit_pause = m.hit_pause
	d.screen_shake = m.screen_shake
	d.grab = m.grab_target
	return d

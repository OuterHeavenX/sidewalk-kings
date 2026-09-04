class_name MoveData
extends Resource
## Data-driven combat move. All timing is in 60fps frames. Player and enemies both use these.

enum InputKind { NONE, LIGHT, HEAVY, SPECIAL, JUMP, GRAB }
enum Requirement { ANY, GROUNDED, AIRBORNE, RUNNING, GRABBING }
enum DamageKind { PUNCH, KICK, THROW, WEAPON, SPECIAL, BODY }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var animation: String = "punch1"
@export var input: InputKind = InputKind.LIGHT
@export var requirement: Requirement = Requirement.GROUNDED
@export var damage_kind: DamageKind = DamageKind.PUNCH

@export_group("Timing (frames @60fps)")
@export var startup: int = 4
@export var active: int = 3
@export var recovery: int = 8
## Frames after the hit connects during which a follow-up input is accepted.
@export var cancel_window: int = 14
## Frames of stun applied to the target.
@export var hitstun: int = 14

@export_group("Damage & physics")
@export var damage: int = 6
@export var knockback: Vector2 = Vector2(60, 0)
@export var launch_force: float = 0.0
@export var knockdown: bool = false
@export var energy_cost: float = 0.0
@export var special_cost: float = 0.0
@export var forward_move: float = 0.0        # px the attacker slides forward during startup
@export var self_launch: float = 0.0         # vertical launch applied to the attacker (flying knee etc.)
@export var grab_target: bool = false        # move initiates a grab on hit
@export var multi_hit: int = 1
@export var armor: bool = false              # attacker ignores light hitstun during the move

@export_group("Hitbox")
@export var hitbox_offset: Vector2 = Vector2(18, -22)
@export var hitbox_size: Vector2 = Vector2(22, 18)
@export var lane_tolerance: float = 14.0

@export_group("Followups")
## Move ids reachable from this move, checked against the pressed input kind.
@export var followups: Array[String] = []

@export_group("Feel")
@export var sound: String = "punch_light"
@export var hit_sound: String = "hit_light"
@export var screen_shake: float = 0.0
@export var hit_pause: float = 0.04
@export var hit_fx: String = "spark_small"
@export var camera_kick: float = 0.0

@export_group("Unlock (dojo/books)")
@export var price: int = 0
@export var required_level: int = 1
@export var required_stat: String = ""
@export var required_stat_value: int = 0
@export var required_move: String = ""
@export var required_flag: String = ""
@export var learnable: bool = false

func total_frames() -> int:
	return startup + active + recovery

func is_heavy() -> bool:
	return input == InputKind.HEAVY or damage_kind == DamageKind.THROW or damage_kind == DamageKind.SPECIAL

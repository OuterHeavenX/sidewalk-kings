class_name EnemyData
extends Resource
## Describes an enemy archetype instance: stats, AI style, look, drops. Used by EnemyBase + EnemyDirector.

enum Archetype { GRUNT, RUSHER, GRAPPLER, WEAPON_USER, HEAVY, RANGED, BOSS }

@export var id: String = ""
@export var display_name: String = "Thug"
@export var gang: String = "pigeons"
@export var archetype: Archetype = Archetype.GRUNT
@export var sprite_frames: SpriteFrames
@export var portrait: Texture2D

@export_group("Stats")
@export var max_hp: int = 30
@export var damage_multiplier: float = 1.0
@export var defense: float = 0.0            # flat damage reduction
@export var move_speed: float = 70.0
@export var run_speed: float = 130.0
@export var weight: float = 1.0             # 1 = normal knockback; heavier = less
@export var armor_threshold: int = 0        # damage below this doesn't stagger (heavies)
@export var grab_resist: float = 0.0        # 0..1 chance to break a grab attempt
@export var can_be_grabbed: bool = true

@export_group("AI")
@export var preferred_distance: float = 34.0
@export var aggression: float = 0.5         # 0..1 how often it decides to attack when in range
@export var reaction_delay: float = 0.35
@export var attack_cooldown: float = 1.1
@export var circle_chance: float = 0.4
@export var picks_up_weapons: bool = false
@export var ranged_distance: float = 140.0
@export var moves: Array[String] = ["enemy_jab", "enemy_kick"]
@export var heavy_move: String = ""
@export var ranged_move: String = ""

@export_group("Rewards")
@export var xp: int = 8
@export var money_min: int = 3
@export var money_max: int = 9
@export var drop_table: Array[String] = []    # item ids, chance handled by director
@export var drop_chance: float = 0.12

@export_group("Presentation")
@export var scale: float = 1.0
@export var tint: Color = Color.WHITE
@export var taunts: Array[String] = ["You picked the wrong block."]
@export var defeat_lines: Array[String] = ["...ow."]
@export var show_health_bar: bool = true

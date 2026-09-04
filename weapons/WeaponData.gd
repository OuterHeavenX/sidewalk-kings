class_name WeaponData
extends Resource
## Environmental weapon definition. Future weapons are new .tres files, not new scripts.

enum Style { SWING, BLUNT, THROW_ONLY, BOUNCE }

@export var id: String = ""
@export var display_name: String = "Weapon"
@export var texture: Texture2D
@export var style: Style = Style.SWING
@export var damage: int = 12
@export var durability: int = 6            # hits before it breaks (-1 = never)
@export var breaks: bool = true
@export var swing_move: String = "weapon_swing"
@export var throw_damage: int = 14
@export var throw_speed: float = 320.0
@export var weight: float = 1.0            # affects swing speed/knockback
@export var knockback: Vector2 = Vector2(110, 0)
@export var knockdown: bool = false
@export var hit_sound: String = "hit_weapon"
@export var swing_sound: String = "whoosh_heavy"
@export var break_sound: String = "weapon_break"
@export var hand_offset: Vector2 = Vector2(14, -26)
@export var rotation_degrees_held: float = -35.0
@export var bounces_on_throw: bool = false
@export var shop_price: int = 0

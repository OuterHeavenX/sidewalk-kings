class_name BookData
extends Resource
## Books unlock moves, passives or grant stat bonuses when read.

@export var id: String = ""
@export var display_name: String = "Book"
@export var price: int = 50
@export_multiline var description: String = ""
@export var blurb: String = ""
@export var unlock_move: String = ""
@export var stat: String = ""          # strength/defense/speed/stamina/technique/luck
@export var stat_bonus: int = 0
@export var bonus: String = ""         # PlayerState.BONUS_NAMES key
@export var bonus_amount: int = 0
@export var required_level: int = 1
@export var icon: Texture2D

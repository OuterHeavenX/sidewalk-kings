class_name FoodData
extends Resource
## Food sold at restaurants and stores. Heals and/or permanently boosts stats.

@export var id: String = ""
@export var display_name: String = "Snack"
@export var price: int = 5
@export var heal: int = 10
@export var energy: int = 0
@export var strength_bonus: int = 0
@export var defense_bonus: int = 0
@export var speed_bonus: int = 0
@export var stamina_bonus: int = 0
@export var technique_bonus: int = 0
@export var luck_bonus: int = 0
@export var max_hp_bonus: int = 0
@export_multiline var description: String = "It's food."
@export var icon: Texture2D
@export var takeout: bool = false   # can be carried in inventory and eaten later
@export var eat_line: String = ""

func stat_summary() -> String:
	var parts: PackedStringArray = []
	if heal > 0: parts.append("+%d HP" % heal)
	if energy > 0: parts.append("+%d EN" % energy)
	if strength_bonus > 0: parts.append("STR+%d" % strength_bonus)
	if defense_bonus > 0: parts.append("DEF+%d" % defense_bonus)
	if speed_bonus > 0: parts.append("SPD+%d" % speed_bonus)
	if stamina_bonus > 0: parts.append("STA+%d" % stamina_bonus)
	if technique_bonus > 0: parts.append("TEC+%d" % technique_bonus)
	if luck_bonus > 0: parts.append("LCK+%d" % luck_bonus)
	if max_hp_bonus > 0: parts.append("MaxHP+%d" % max_hp_bonus)
	return " ".join(parts)

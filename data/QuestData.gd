class_name QuestData
extends Resource
## Lightweight quest definition. Objective progress is tracked by QuestManager.

enum Objective { DEFEAT_GANG, DEFEAT_ENEMY_ID, DEFEAT_BOSS, COLLECT_ITEM, DELIVER_ITEM, TALK_TO, REACH_AREA, FLAG }

@export var id: String = ""
@export var title: String = "Quest"
@export_multiline var description: String = ""
@export var giver: String = ""
@export var objective: Objective = Objective.DEFEAT_GANG
@export var target: String = ""          # gang id / enemy id / item id / npc id / area id / flag
@export var required_count: int = 1
@export var turn_in_npc: String = ""      # empty = auto-complete when objective is met
@export var reward_money: int = 0
@export var reward_xp: int = 0
@export var reward_items: Array[String] = []
@export var reward_move: String = ""
@export var reward_flag: String = ""
@export var optional: bool = true
@export var hint: String = ""

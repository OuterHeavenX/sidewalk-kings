class_name DialogueData
extends Resource
## A conversation. Each line is a Dictionary:
##   {"name": "Dez", "portrait": "dez", "text": "...", "choices": [{"text": "...", "goto": 3}], "goto": 5,
##    "set_flag": "met_dez", "start_quest": "q_id", "complete_quest": "q_id", "give_item": "id", "give_money": 20,
##    "if_flag": "flag", "if_not_flag": "flag", "end": true, "shop": "shop_id"}
## Keep dialogue in data; DialogueManager only interprets.

@export var id: String = ""
@export var lines: Array[Dictionary] = []
@export var pause_game: bool = true
@export var once_flag: String = ""     # if set, dialogue is marked seen with this flag

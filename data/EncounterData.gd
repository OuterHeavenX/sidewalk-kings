class_name EncounterData
extends Resource
## Spawn data for the EnemyDirector. Waves are arrays of {"enemy": id, "count": n, "side": "left|right|any"}.

@export var id: String = ""
@export var gang: String = ""
@export var waves: Array[Dictionary] = []
@export var max_active: int = 4
@export var difficulty_scale_per_level: float = 0.06
@export var lock_camera: bool = true
@export var once_flag: String = ""          # if set, encounter won't respawn after clearing
@export var respawn_on_reenter: bool = true
@export var boss_id: String = ""
@export var reward_flag: String = ""
@export var music: String = ""
@export var intro_dialogue: String = ""
@export var clear_dialogue: String = ""

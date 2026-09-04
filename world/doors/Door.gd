class_name Door
extends Node2D
## Travel point: doorways into shops and interiors, plus street-edge transitions.

@export var door_id: String = ""
@export var to_area: String = ""
@export var to_spawn: String = "start"
@export var label: String = "Enter"
@export var shop_id: String = ""            # if set, opens a shop instead of changing area
@export var required_flag: String = ""
@export var locked_message: String = "It's locked."
@export var auto: bool = false               # street edge: walk into it to travel
@export var edge_direction: int = 0          # -1 left edge, 1 right edge, 0 not an edge

var _cooldown: float = 0.0

@onready var prompt: Node2D = $Prompt
@onready var area: Area2D = $Area

func _ready() -> void:
	add_to_group("doors")
	if not auto:
		add_to_group("interactables")
	if prompt:
		prompt.visible = false
	if area:
		area.body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

func get_interact_prompt() -> String:
	return label

func _on_body_entered(body: Node) -> void:
	if auto and body.is_in_group("player") and _cooldown <= 0.0:
		interact(body)

func interact(by: Node) -> void:
	if _cooldown > 0.0 or SceneManager.is_busy():
		return
	if required_flag != "" and not GameManager.get_flag(required_flag):
		DialogueManager.say("", locked_message)
		return
	_cooldown = 1.0
	if shop_id != "":
		AudioManager.play_sfx("door", -6.0)
		ShopManager.open_shop(shop_id)
		return
	if to_area == "":
		return
	AudioManager.play_sfx("door", -4.0)
	EventBus.door_used.emit(door_id)
	SceneManager.change_area(to_area, to_spawn)

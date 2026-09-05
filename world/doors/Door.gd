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

## How far away the marker starts to show. The HUD prompt uses 26, which tells you a door
## is there once you are already standing in it -- fine for a door you can see, useless for
## one you cannot. Playtesting found the fire escape by walking the street pressing the
## interact key, which is not finding it.
const MARKER_RANGE := 108.0

var _cooldown: float = 0.0
var _marker: Sprite2D = null
var _bob: float = 0.0

@onready var prompt: Node2D = $Prompt
@onready var area: Area2D = $Area

func _ready() -> void:
	add_to_group("doors")
	if not auto:
		add_to_group("interactables")
		_build_marker()
	if prompt:
		prompt.visible = false
	if area:
		area.body_entered.connect(_on_body_entered)

## A chevron hanging over the door. Only interactable doors get one: an edge door is the
## end of the street and walking into it is how you already expect to leave.
func _build_marker() -> void:
	var tex: Texture2D = load("res://assets/art/props/door_marker.png")
	if tex == null:
		return
	_marker = Sprite2D.new()
	_marker.texture = tex
	_marker.position = Vector2(0, -44)
	_marker.z_index = 40
	_marker.light_mask = 0        # a signpost, not a lit object; it must not go dark at night
	_marker.modulate = Color(1, 1, 1, 0)
	add_child(_marker)

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	_update_marker(delta)

func _update_marker(delta: float) -> void:
	if _marker == null:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not GameManager.is_gameplay_active():
		_marker.modulate.a = maxf(0.0, _marker.modulate.a - delta * 4.0)
		return
	# Locked doors still show the marker. A door you cannot open yet is information; a door
	# you cannot see is a dead end that looks like a wall.
	var d: float = global_position.distance_to(player.global_position)
	var want: float = clampf(1.0 - (d - 26.0) / (MARKER_RANGE - 26.0), 0.0, 1.0)
	_marker.modulate.a = move_toward(_marker.modulate.a, want, delta * 3.5)
	_bob += delta * 3.2
	# Integer pixels: the project snaps 2D transforms, so a fractional bob judders.
	_marker.position.y = -44.0 + roundf(sin(_bob) * 2.0)
	# Close enough to use, it pushes past 1.0 and picks up the bloom the streets already use.
	var g: float = 1.0 + (0.85 if d < 30.0 else 0.0)
	_marker.modulate.r = g
	_marker.modulate.g = g
	_marker.modulate.b = g

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

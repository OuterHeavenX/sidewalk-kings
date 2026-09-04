class_name NPC
extends Node2D
## A friendly character: shopkeepers, locals, quest givers.
## Dialogue is chosen from a list of conditional entries so lines change as the story moves.

@export var npc_id: String = "dez"
@export var display_name: String = "Local"
@export var character: String = "dez"
@export var dialogue_id: String = ""
@export var shop_id: String = ""
@export var wander: bool = false
@export var wander_range: float = 24.0
@export var face_player: bool = true
## Each entry: {"dialogue": id, "if_flag": "...", "if_not_flag": "...", "if_quest": ["id","state"]}
@export var conditional_dialogue: Array[Dictionary] = []

var z_height: float = 0.0
var facing: int = 1
var _home_x: float = 0.0
var _wander_target: float = 0.0
var _wander_timer: float = 0.0
var talking: bool = false

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var prompt: Node2D = $Prompt

func _ready() -> void:
	add_to_group("npcs")
	add_to_group("interactables")
	_home_x = position.x
	_wander_target = position.x
	_load_frames()
	if prompt:
		prompt.visible = false
	_play("idle")

func _load_frames() -> void:
	var path := "res://assets/art/characters/%s_frames.tres" % character
	if ResourceLoader.exists(path) and sprite:
		sprite.sprite_frames = load(path)

func _play(anim: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		if sprite.animation != anim or not sprite.is_playing():
			sprite.play(anim)

func _process(delta: float) -> void:
	if talking or not GameManager.is_gameplay_active():
		_play("talk" if talking else "idle")
		if talking and face_player and is_instance_valid(GameManager.player):
			facing = 1 if GameManager.player.global_position.x > global_position.x else -1
		_apply_facing()
		return
	if wander:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_wander_timer = randf_range(1.5, 4.0)
			_wander_target = _home_x + randf_range(-wander_range, wander_range)
		var dx := _wander_target - position.x
		if absf(dx) > 2.0:
			position.x += signf(dx) * 26.0 * delta
			facing = signi(int(signf(dx)))
			_play("walk")
		else:
			_play("idle")
	else:
		_play("idle")
	_apply_facing()

func _apply_facing() -> void:
	if sprite:
		sprite.flip_h = facing < 0

func get_interact_prompt() -> String:
	if shop_id != "":
		var s: ShopData = ContentDB.get_shop(shop_id)
		return "Shop" if s == null else s.display_name
	return "Talk"

func interact(by: Node) -> void:
	if talking:
		return
	talking = true
	if face_player and is_instance_valid(by):
		facing = 1 if by.global_position.x > global_position.x else -1
	var did := _resolve_dialogue()
	if did != "":
		DialogueManager.start(did, npc_id, _on_done)
	elif shop_id != "":
		ShopManager.open_shop(shop_id)
		talking = false
		QuestManager.notify_talked_to(npc_id)
	else:
		DialogueManager.say(display_name, "...")
		talking = false

func _on_done() -> void:
	talking = false

func _resolve_dialogue() -> String:
	for entry in conditional_dialogue:
		if entry.has("if_flag") and not GameManager.get_flag(str(entry["if_flag"])):
			continue
		if entry.has("if_not_flag") and GameManager.get_flag(str(entry["if_not_flag"])):
			continue
		if entry.has("if_quest"):
			var spec: Array = entry["if_quest"]
			if QuestManager.get_state(str(spec[0])) != str(spec[1]):
				continue
		if entry.has("if_has_item") and not GameManager.has_item(str(entry["if_has_item"])):
			continue
		return str(entry.get("dialogue", ""))
	return dialogue_id

class_name Prop
extends Node2D
## Street furniture. Some props are decorative, some are solid, some break open and
## spill money, food or a weapon. All configured from the area layout data.

@export var prop_id: String = "trashcan"
@export var solid: bool = false
@export var breakable: bool = false
@export var hp: int = 12
@export var contains: String = ""          # item id, weapon id ("weapon:bat") or "" for money
@export var money: int = 0
@export var flag_when_broken: String = ""
@export var searchable: bool = false        # interact instead of hit (vending machines etc.)
@export var interact_dialogue: String = ""
@export var interact_prompt: String = "Search"

var dead: bool = false
var z_height: float = 0.0
var searched: bool = false

@onready var sprite: Sprite2D = $Sprite
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var body: StaticBody2D = $Body

func _ready() -> void:
	add_to_group("props")
	_load_texture()
	if hurtbox:
		hurtbox.active = breakable
		hurtbox.actor = self
	if body:
		body.collision_layer = 1 if solid else 0
		var col: CollisionShape2D = body.get_node_or_null("Shape")
		if col and sprite and sprite.texture:
			var rect := RectangleShape2D.new()
			rect.size = Vector2(maxf(10.0, sprite.texture.get_width() * 0.7), 8.0)
			col.shape = rect
	if searchable:
		add_to_group("interactables")

func _load_texture() -> void:
	var path := "res://assets/art/props/%s.png" % prop_id
	if sprite == null:
		return
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if tex == null:
		push_warning("[Prop] missing texture for '%s'" % prop_id)
		return
	sprite.texture = tex
	# A vending machine, a lit ticket screen or a lamp head glows; the rest do not.
	Emission.attach(sprite, prop_id, sprite, 1)
	# Anchor the sprite so its base sits on the prop's ground position.
	sprite.offset.y = -float(tex.get_height()) * 0.5

func get_interact_prompt() -> String:
	return interact_prompt

func interact(by: Node) -> void:
	if interact_dialogue != "":
		DialogueManager.start(interact_dialogue)
		return
	if searched:
		DialogueManager.say("", "Nothing left in there.")
		return
	searched = true
	AudioManager.play_sfx("pickup", -6.0)
	_spill()

func take_damage(d: DamageData) -> bool:
	if not breakable or dead:
		return false
	hp -= d.amount
	AudioManager.play_sfx("hit_weapon", -8.0)
	FX.spawn("spark_small", global_position + Vector2(0, -14), get_parent())
	if sprite:
		sprite.modulate = Color(2.0, 2.0, 2.0)
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)
		var tw2 := create_tween()
		tw2.tween_property(sprite, "position:x", d.direction * 3.0, 0.05)
		tw2.tween_property(sprite, "position:x", 0.0, 0.08)
	if hp <= 0:
		_break()
	return true

func _break() -> void:
	dead = true
	AudioManager.play_sfx("break_object", -4.0)
	EventBus.screen_shake.emit(2.0, 0.15)
	FX.spawn("spark_big", global_position + Vector2(0, -16), get_parent())
	FX.dust(global_position, get_parent())
	_spill()
	if flag_when_broken != "":
		GameManager.set_flag(flag_when_broken, true)
	if body:
		body.collision_layer = 0
	if hurtbox:
		hurtbox.active = false
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.25)
	tw.tween_property(sprite, "position:y", 6.0, 0.25)
	tw.chain().tween_callback(queue_free)

func _spill() -> void:
	if contains.begins_with("weapon:"):
		var wid := contains.substr(7)
		var scene: PackedScene = load("res://weapons/Weapon.tscn")
		var w = scene.instantiate()
		w.weapon_id = wid
		get_parent().add_child(w)
		w.global_position = global_position
		w.drop_from(global_position)
	elif contains != "":
		var scene2: PackedScene = load("res://world/props/ItemPickup.tscn")
		var p = scene2.instantiate()
		get_parent().add_child(p)
		var res := ContentDB.get_item(contains)
		var key: bool = res != null and res is ItemData and (res as ItemData).kind == ItemData.Kind.KEY
		p.setup(contains, global_position, Vector2(randf_range(-30, 30), 0), 140.0, key)
	if money > 0:
		var mscene: PackedScene = load("res://world/props/MoneyPickup.tscn")
		var coins := clampi(int(ceil(money / 8.0)), 1, 5)
		for i in coins:
			var c = mscene.instantiate()
			get_parent().add_child(c)
			c.setup(maxi(1, money / coins), global_position, Vector2(randf_range(-50, 50), 0), randf_range(110.0, 170.0))

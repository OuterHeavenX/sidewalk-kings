class_name FX
extends Node
## Visual effects helper: hit sparks, dust, rings, floating numbers.
## Purely static; Game.gd calls FX.setup() with the node effects should be parented to.

const FX_DIR := "res://assets/art/fx/"

static var _textures: Dictionary = {}
static var _root: Node = null

static func setup(root: Node) -> void:
	_root = root

static func _get_texture(id: String) -> Texture2D:
	if _textures.has(id):
		return _textures[id]
	var path := FX_DIR + id + ".png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_textures[id] = tex
	return tex

## Spawn a 4-frame FX strip at a world position.
static func spawn(id: String, world_pos: Vector2, parent: Node = null, scale_mul: float = 1.0) -> void:
	if id == "":
		return
	var tex := _get_texture(id)
	if tex == null:
		return
	var host: Node = parent if parent != null and is_instance_valid(parent) else _root
	if host == null or not is_instance_valid(host):
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.hframes = 4
	s.frame = 0
	s.global_position = world_pos
	s.z_index = 60
	s.scale = Vector2(scale_mul, scale_mul)
	s.rotation = randf_range(-0.4, 0.4)
	host.add_child(s)
	var tw := s.create_tween()
	for i in 4:
		tw.tween_callback(func(): if is_instance_valid(s): s.frame = i)
		tw.tween_interval(0.045)
	tw.tween_callback(s.queue_free)

## How many stains one actor is allowed to leave before the oldest starts fading. Without a
## cap a long fight in one street quietly accumulates hundreds of sprites.
const MAX_STAINS_PER_ACTOR := 4

## Stains on the floor, keyed by the instance id of whoever bled them, so they can be taken
## away again when that actor goes. Keying on the object itself would keep a freed enemy
## alive in this dictionary.
static var _stains: Dictionary = {}

## The loud version of a landed hit: a burst that punches up past its own size before it
## settles, plus streaks thrown out along the direction of the blow.
##
## The plain 4-frame spark is still drawn underneath. This sits on top of it, because the
## thing that reads as impact is not the shape, it is the shape changing size fast.
static func impact(world_pos: Vector2, dir: int, kind: String, parent: Node = null) -> void:
	var host: Node = parent if parent != null and is_instance_valid(parent) else _root
	if host == null or not is_instance_valid(host):
		return
	var tex := _get_texture(kind)
	if tex != null:
		var s := Sprite2D.new()
		s.texture = tex
		s.hframes = 4
		s.frame = 0
		s.global_position = world_pos
		s.z_index = 62
		s.rotation = randf_range(-PI, PI)
		s.scale = Vector2(0.55, 0.55)
		host.add_child(s)
		var pop := s.create_tween()
		pop.tween_property(s, "scale", Vector2(1.25, 1.25), 0.05).set_ease(Tween.EASE_OUT)
		pop.tween_property(s, "scale", Vector2(0.95, 0.95), 0.09).set_ease(Tween.EASE_IN)
		var anim := s.create_tween()
		for i in 4:
			anim.tween_callback(func(): if is_instance_valid(s): s.frame = i)
			anim.tween_interval(0.04)
		anim.tween_callback(s.queue_free)

	# Streaks. Short lines are cheap and sell direction better than any sprite: they say
	# which way the hit went, which a radially symmetric burst cannot.
	var star_tex := _get_texture("star")
	if star_tex == null:
		return
	for i in range(4):
		var k := Sprite2D.new()
		k.texture = star_tex
		k.global_position = world_pos
		k.z_index = 63
		k.scale = Vector2(randf_range(0.5, 0.9), randf_range(0.25, 0.4))
		var ang := randf_range(-0.85, 0.85) + (0.0 if dir >= 0 else PI)
		k.rotation = ang
		host.add_child(k)
		var dist := randf_range(16.0, 34.0)
		var tw := k.create_tween()
		tw.set_parallel(true)
		tw.tween_property(k, "global_position",
			world_pos + Vector2(cos(ang), sin(ang) * 0.6) * dist, 0.20).set_ease(Tween.EASE_OUT)
		tw.tween_property(k, "scale", Vector2(0.1, 0.1), 0.20)
		tw.tween_property(k, "modulate:a", 0.0, 0.20)
		tw.chain().tween_callback(k.queue_free)

## Droplets that arc out of a hit, land on the ground, and stay there as stains.
##
## `ground_y` is lane depth, not screen height: in this projection an actor's y IS the floor
## it stands on, so a droplet lands by tweening to the y of whoever bled it.
static func blood(world_pos: Vector2, dir: int, owner: Node, ground_y: float,
		count: int = 4, parent: Node = null) -> void:
	var host: Node = parent if parent != null and is_instance_valid(parent) else _root
	if host == null or not is_instance_valid(host) or owner == null:
		return
	var drop_tex := _get_texture("blood_drop")
	if drop_tex == null:
		return
	for i in range(count):
		var d := Sprite2D.new()
		d.texture = drop_tex
		d.global_position = world_pos
		d.z_index = 58
		host.add_child(d)
		var land := Vector2(
			world_pos.x + dir * randf_range(2.0, 26.0) + randf_range(-6.0, 6.0),
			ground_y + randf_range(-4.0, 5.0))
		var owner_id := owner.get_instance_id()
		var tw := d.create_tween()
		# EASE_IN so it accelerates downward and reads as falling rather than sliding.
		tw.tween_property(d, "global_position", land, randf_range(0.18, 0.34)).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			if is_instance_valid(d):
				d.queue_free()
			_stain(land, owner_id, host))

## One stain, registered to whoever bled it.
static func _stain(at: Vector2, owner_id: int, host: Node) -> void:
	if host == null or not is_instance_valid(host):
		return
	var tex := _get_texture("blood_splat_%d" % (randi() % 3))
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.global_position = at
	# Under the actors and over the road. A stain drawn on top of people is a sticker.
	s.z_index = -2
	s.rotation = randf_range(-PI, PI)
	var sc := randf_range(0.4, 0.72)
	s.scale = Vector2(sc, sc * 0.6)       # squashed, because the floor is seen at an angle
	s.modulate = Color(1, 1, 1, 0.62)
	host.add_child(s)

	if not _stains.has(owner_id):
		_stains[owner_id] = []
	var list: Array = _stains[owner_id]
	list.append(s)
	while list.size() > MAX_STAINS_PER_ACTOR:
		var old: Sprite2D = list.pop_front() as Sprite2D
		if old != null and is_instance_valid(old):
			var fade: Tween = old.create_tween()
			fade.tween_property(old, "modulate:a", 0.0, 0.5)
			fade.tween_callback(old.queue_free)

## Take an actor's stains away with them. Called when an enemy finishes dying, so the floor
## goes back to how it was rather than keeping a record of everyone who has ever stood there.
static func clear_blood(owner: Node, fade: float = 0.45) -> void:
	if owner == null:
		return
	var owner_id := owner.get_instance_id()
	if not _stains.has(owner_id):
		return
	for entry in _stains[owner_id]:
		var s: Sprite2D = entry as Sprite2D
		if s == null or not is_instance_valid(s):
			continue
		var tw: Tween = s.create_tween()
		tw.tween_property(s, "modulate:a", 0.0, fade)
		tw.tween_callback(s.queue_free)
	_stains.erase(owner_id)

## Drop every registration. Areas free their own children, so the sprites are already gone;
## this stops the dictionary growing an entry per enemy per area for the whole session.
static func forget_blood() -> void:
	_stains.clear()

## Floating damage / money number.
static func number(text: String, world_pos: Vector2, color: Color, parent: Node = null, big: bool = false) -> void:
	var host: Node = parent if parent != null and is_instance_valid(parent) else _root
	if host == null or not is_instance_valid(host):
		return
	var l := Label.new()
	l.text = text
	l.z_index = 70
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_font_size_override("font_size", 12 if big else 9)
	l.global_position = world_pos + Vector2(randf_range(-4, 4), 0)
	host.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - (22.0 if big else 15.0), 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)

## A blocked hit: a bright clang rather than an impact spark.
static func spark_guard(world_pos: Vector2, parent: Node = null) -> void:
	spawn("spark_weapon", world_pos, parent, 0.85)

static func dust(world_pos: Vector2, parent: Node = null) -> void:
	spawn("dust", world_pos, parent)

static func stars(world_pos: Vector2, parent: Node = null, count: int = 3) -> void:
	var tex := _get_texture("star")
	if tex == null:
		return
	var host: Node = parent if parent != null and is_instance_valid(parent) else _root
	if host == null:
		return
	for i in count:
		var s := Sprite2D.new()
		s.texture = tex
		s.global_position = world_pos
		s.z_index = 65
		host.add_child(s)
		var ang := randf_range(-PI, 0.0)
		var dist := randf_range(10.0, 22.0)
		var tw := s.create_tween()
		tw.set_parallel(true)
		tw.tween_property(s, "global_position", world_pos + Vector2(cos(ang), sin(ang)) * dist, 0.45)
		tw.tween_property(s, "modulate:a", 0.0, 0.45)
		tw.tween_property(s, "rotation", randf_range(-4.0, 4.0), 0.45)
		tw.chain().tween_callback(s.queue_free)

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

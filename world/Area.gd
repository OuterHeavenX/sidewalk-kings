class_name Area
extends Node2D
## A playable street or interior, built at runtime from a JSON layout in res://data/areas/.
##
## Adding a new neighbourhood means adding a layout file and its content data. No new
## scenes or scripts are required, which is what keeps future expansion cheap.

const LAYOUT_DIR := "res://data/areas/"

var area_id: String = ""
var layout: Dictionary = {}
var meta: AreaData = null

var lane_min: float = 0.0
var lane_max: float = 40.0
var walk_min_x: float = 0.0
var walk_max_x: float = 800.0
var ground_y: float = 0.0

var director: EnemyDirector = null
var camera: GameCamera = null

@onready var parallax: Node2D = $Parallax
@onready var ground_root: Node2D = $Ground
@onready var actors_root: Node2D = $Actors
@onready var front_root: Node2D = $Front
@onready var triggers_root: Node2D = $Triggers

var _parallax_layers: Array[Dictionary] = []
var _encounter_triggers: Array[Dictionary] = []
var _spawn_points: Dictionary = {}
var _tile_cache: Dictionary = {}

func build(id: String, cam: GameCamera) -> void:
	area_id = id
	camera = cam
	meta = ContentDB.get_area(id)
	layout = _load_layout(id)
	if layout.is_empty():
		push_error("[Area] No layout for '%s'" % id)
		return
	lane_min = float(layout.get("lane_min", 26.0))
	lane_max = float(layout.get("lane_max", 58.0))
	walk_min_x = float(layout.get("walk_min_x", 16.0))
	walk_max_x = float(layout.get("walk_max_x", 900.0))
	ground_y = float(layout.get("ground_y", 0.0))
	actors_root.y_sort_enabled = true
	_build_parallax()
	_build_ground()
	_build_props()
	_build_weapons()
	_build_npcs()
	_build_doors()
	_build_spawns()
	_build_triggers()
	director = EnemyDirector.new()
	director.name = "EnemyDirector"
	director.setup(self)
	add_child(director)

func _load_layout(id: String) -> Dictionary:
	var path := LAYOUT_DIR + id + ".json"
	if not FileAccess.file_exists(path):
		push_error("[Area] Missing layout file: " + path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}

# ---------------- Construction ----------------
func _tex(path: String) -> Texture2D:
	if _tile_cache.has(path):
		return _tile_cache[path]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tile_cache[path] = t
	return t

func _build_parallax() -> void:
	for entry in layout.get("parallax", []):
		var tex := _tex(str(entry.get("texture", "")))
		if tex == null:
			continue
		var holder := Node2D.new()
		holder.name = "PLayer%d" % _parallax_layers.size()
		parallax.add_child(holder)
		var scroll := float(entry.get("scroll", 0.5))
		var y := float(entry.get("y", 0.0))
		var repeat := int(entry.get("repeat", 6))
		var scale_v := float(entry.get("scale", 1.0))
		var tint: Variant = entry.get("modulate", null)
		for i in repeat:
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.scale = Vector2(scale_v, scale_v)
			s.position = Vector2(i * tex.get_width() * scale_v, y)
			if tint is Array and (tint as Array).size() >= 3:
				var t: Array = tint
				s.modulate = Color(t[0], t[1], t[2], t[3] if t.size() > 3 else 1.0)
			holder.add_child(s)
		holder.z_index = int(entry.get("z", -50))
		_parallax_layers.append({"node": holder, "scroll": scroll, "width": tex.get_width() * scale_v * repeat})

func _build_ground() -> void:
	# Ground strips: repeating 16px tiles across the area width.
	var tileset := _tex("res://assets/art/tilesets/city_tiles.png")
	for strip in layout.get("ground", []):
		var tile_name := str(strip.get("tile", "sidewalk_a"))
		var y := float(strip.get("y", 0.0))
		var h := int(strip.get("height", 1))
		var x0 := float(strip.get("x", walk_min_x - 40.0))
		var x1 := float(strip.get("x2", walk_max_x + 40.0))
		var idx := _tile_index(tile_name)
		if tileset == null or idx.x < 0:
			var cr := ColorRect.new()
			cr.color = Color(0.3, 0.29, 0.34)
			cr.position = Vector2(x0, y)
			cr.size = Vector2(x1 - x0, h * 16)
			cr.z_index = int(strip.get("z", -20))
			ground_root.add_child(cr)
			continue
		var x := x0
		var alt := str(strip.get("alt", ""))
		var alt_idx := _tile_index(alt) if alt != "" else Vector2(-1, -1)
		var n := 0
		while x < x1:
			for row in h:
				var s := Sprite2D.new()
				s.texture = tileset
				s.region_enabled = true
				var use := idx
				if alt_idx.x >= 0 and (n + row) % 2 == 1:
					use = alt_idx
				s.region_rect = Rect2(use.x * 16, use.y * 16, 16, 16)
				s.centered = false
				s.position = Vector2(x, y + row * 16)
				s.z_index = int(strip.get("z", -20))
				ground_root.add_child(s)
			x += 16
			n += 1

const TILE_NAMES := ["sidewalk_a", "sidewalk_b", "asphalt_a", "asphalt_b", "asphalt_line", "curb",
	"brick_red", "brick_tan", "concrete", "metal", "tile_floor", "dirt", "wood_floor"]

func _tile_index(name: String) -> Vector2:
	var i := TILE_NAMES.find(name)
	if i < 0:
		return Vector2(-1, -1)
	return Vector2(i % 8, i / 8)

func _build_props() -> void:
	var prop_scene: PackedScene = load("res://world/props/Prop.tscn")
	for entry in layout.get("scenery", []):
		# Flat decoration: buildings, awnings, graffiti. No behaviour.
		var tex := _tex(str(entry.get("texture", "")))
		if tex == null:
			continue
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.position = Vector2(float(entry.get("x", 0)), float(entry.get("y", 0)))
		s.z_index = int(entry.get("z", -10))
		var sc := float(entry.get("scale", 1.0))
		s.scale = Vector2(sc, sc)
		if entry.has("flip") and bool(entry["flip"]):
			s.flip_h = true
		if entry.has("modulate"):
			var m: Array = entry["modulate"]
			s.modulate = Color(m[0], m[1], m[2], m[3] if m.size() > 3 else 1.0)
		(front_root if bool(entry.get("front", false)) else ground_root).add_child(s)
	for entry in layout.get("props", []):
		var p = prop_scene.instantiate()
		p.prop_id = str(entry.get("id", "trashcan"))
		p.solid = bool(entry.get("solid", false))
		p.breakable = bool(entry.get("breakable", false))
		p.hp = int(entry.get("hp", 12))
		p.contains = str(entry.get("contains", ""))
		p.money = int(entry.get("money", 0))
		p.searchable = bool(entry.get("searchable", false))
		p.interact_dialogue = str(entry.get("dialogue", ""))
		p.interact_prompt = str(entry.get("prompt", "Search"))
		p.flag_when_broken = str(entry.get("flag", ""))
		actors_root.add_child(p)
		p.position = Vector2(float(entry.get("x", 0)), float(entry.get("y", lane_max)))

func _build_weapons() -> void:
	var scene: PackedScene = load("res://weapons/Weapon.tscn")
	for entry in layout.get("weapons", []):
		var w = scene.instantiate()
		w.weapon_id = str(entry.get("id", "bat"))
		actors_root.add_child(w)
		w.position = Vector2(float(entry.get("x", 0)), float(entry.get("y", lane_max - 4)))

func _build_npcs() -> void:
	var scene: PackedScene = load("res://world/NPC.tscn")
	for entry in layout.get("npcs", []):
		if entry.has("if_flag") and not GameManager.get_flag(str(entry["if_flag"])):
			continue
		if entry.has("if_not_flag") and GameManager.get_flag(str(entry["if_not_flag"])):
			continue
		var n = scene.instantiate()
		n.npc_id = str(entry.get("id", "npc"))
		n.display_name = str(entry.get("name", "Local"))
		n.character = str(entry.get("character", "student"))
		n.dialogue_id = str(entry.get("dialogue", ""))
		n.shop_id = str(entry.get("shop", ""))
		n.wander = bool(entry.get("wander", false))
		var cond: Array[Dictionary] = []
		for c in entry.get("conditional", []):
			cond.append(c)
		n.conditional_dialogue = cond
		actors_root.add_child(n)
		n.position = Vector2(float(entry.get("x", 0)), float(entry.get("y", lane_min + 6)))
		if entry.has("facing"):
			n.facing = int(entry["facing"])

func _build_doors() -> void:
	var scene: PackedScene = load("res://world/doors/Door.tscn")
	for entry in layout.get("doors", []):
		var d = scene.instantiate()
		d.door_id = str(entry.get("id", ""))
		d.to_area = str(entry.get("to", ""))
		d.to_spawn = str(entry.get("spawn", "start"))
		d.label = str(entry.get("label", "Enter"))
		d.shop_id = str(entry.get("shop", ""))
		d.required_flag = str(entry.get("required_flag", ""))
		d.locked_message = str(entry.get("locked", "It's locked."))
		d.auto = bool(entry.get("auto", false))
		actors_root.add_child(d)
		d.position = Vector2(float(entry.get("x", 0)), float(entry.get("y", lane_min + 2)))
		var col: CollisionShape2D = d.get_node_or_null("Area/Shape")
		if col:
			var rect := RectangleShape2D.new()
			rect.size = Vector2(float(entry.get("w", 18)), float(entry.get("h", 34)))
			col.shape = rect

func _build_spawns() -> void:
	for entry in layout.get("spawns", []):
		_spawn_points[str(entry.get("id", "start"))] = Vector2(float(entry.get("x", 40)), float(entry.get("y", (lane_min + lane_max) * 0.5)))
	if not _spawn_points.has("start"):
		_spawn_points["start"] = Vector2(walk_min_x + 40.0, (lane_min + lane_max) * 0.5)

func _build_triggers() -> void:
	for entry in layout.get("encounters", []):
		_encounter_triggers.append({
			"encounter": str(entry.get("id", "")),
			"x": float(entry.get("x", 0.0)),
			"width": float(entry.get("width", 40.0)),
			"required_flag": str(entry.get("required_flag", "")),
			"blocked_flag": str(entry.get("blocked_flag", "")),
			"fired": false,
		})

func get_spawn(spawn_id: String) -> Vector2:
	if _spawn_points.has(spawn_id):
		return _spawn_points[spawn_id]
	return _spawn_points.get("start", Vector2(walk_min_x + 40.0, (lane_min + lane_max) * 0.5))

# ---------------- Runtime ----------------
func _process(_delta: float) -> void:
	_update_parallax()
	_check_triggers()

func _update_parallax() -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var cx := camera.global_position.x
	var half := camera.get_viewport_rect().size.x * 0.5
	for layer in _parallax_layers:
		var node: Node2D = layer.node
		# A layer with scroll=1 sticks to the world; scroll=0 sticks to the camera.
		node.position.x = cx * (1.0 - float(layer.scroll)) - half

func _check_triggers() -> void:
	if director == null or director.is_running():
		return
	var p := GameManager.player
	if not is_instance_valid(p) or p.dead or not GameManager.is_gameplay_active():
		return
	for t in _encounter_triggers:
		if t.fired:
			continue
		if t.required_flag != "" and not GameManager.get_flag(t.required_flag):
			continue
		if t.blocked_flag != "" and GameManager.get_flag(t.blocked_flag):
			t.fired = true
			continue
		if absf(p.global_position.x - float(t.x)) <= float(t.width):
			var enc: EncounterData = ContentDB.get_encounter(str(t.encounter))
			if enc == null:
				t.fired = true
				continue
			if enc.once_flag != "" and GameManager.get_flag(enc.once_flag):
				t.fired = true
				continue
			t.fired = true
			director.start_encounter(enc)
			return

func lock_camera(enabled: bool) -> void:
	if camera == null:
		return
	if enabled:
		var p := GameManager.player
		var cx: float = p.global_position.x if is_instance_valid(p) else camera.global_position.x
		camera.lock_to(clampf(cx, walk_min_x + 160.0, walk_max_x - 160.0), 90.0)
	else:
		camera.unlock()

func on_encounter_cleared(encounter_id: String) -> void:
	GameManager.notify("Area clear!", "clear")
	if meta and meta.music != "":
		AudioManager.play_music(meta.music)

## Optional scripted intro/outro dialogue driven by area layout data.
func run_entry_events() -> void:
	for entry in layout.get("on_enter", []):
		if entry.has("if_flag") and not GameManager.get_flag(str(entry["if_flag"])):
			continue
		if entry.has("if_not_flag") and GameManager.get_flag(str(entry["if_not_flag"])):
			continue
		if entry.has("dialogue"):
			DialogueManager.start(str(entry["dialogue"]))
		if entry.has("set_flag"):
			GameManager.set_flag(str(entry["set_flag"]), true)
		if entry.has("start_quest"):
			QuestManager.start_quest(str(entry["start_quest"]))
		return

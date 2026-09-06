class_name MapView
extends Control
## The map of Riverbend, drawn as rooms rather than as a graph.
##
## The first version was a list of area names, which told you nothing a list of area names
## does not already tell you. The second was a node-and-line graph, which told you what
## joins to what and nothing about the places: every street was the same dot, whether it was
## the 700px Line Office or the 1560px platform.
##
## This draws each area as a room sized to the street it actually is. Nothing is authored
## for it: the box widths come from `walk_max_x` in the area layout, the arrangement from
## `map_position`, the joins from `connections`. Adding an area puts it on the map with no
## map work, and the map cannot disagree with the world.
##
## A room you have not been to is drawn as a bare outline if somewhere you HAVE been opens
## onto it, and not at all otherwise. Knowing a door leads somewhere without knowing where
## is the whole shape of a map like this.

signal travel_requested(area_id: String)

const PAD := Vector2(8.0, 10.0)
## One grid step. Rooms are whole numbers of cells so their walls line up with neighbours.
const CELL := Vector2(34.0, 20.0)
const GAP := 4.0
## How much street buys another cell of width. The shortest area is 700px and the longest
## 1560, so this spreads them across a readable one-to-three.
const PX_PER_CELL := 560.0

static var _layouts: Dictionary = {}

var buttons: Array[Button] = []

var _rooms: Dictionary = {}       # area id -> Rect2 in local space
var _current: String = ""
var _selected: String = ""

func build(current_area: String, can_travel: bool) -> void:
	_current = current_area
	for c in get_children():
		c.queue_free()
	buttons.clear()
	_rooms.clear()

	var ids: Array[String] = []
	for id in ContentDB.areas.keys():
		ids.append(str(id))
	ids.sort()
	if ids.is_empty():
		return

	_place_rooms(ids)
	_fit_to_panel()

	for id in ids:
		if not _visited(id) or id == _current or not can_travel:
			continue
		var r: Rect2 = _rooms[id]
		var b := Button.new()
		b.text = ""
		b.tooltip_text = "%s  —  %s" % [ContentDB.areas[id].display_name, ContentDB.areas[id].district]
		b.position = r.position
		b.custom_minimum_size = r.size
		b.size = r.size
		b.focus_mode = Control.FOCUS_ALL
		# The room is its own highlight, drawn in _draw(). A default focus rectangle sitting
		# on top of a room outline is two boxes saying the same thing.
		var clear := UITheme.panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0)
		for st in ["focus", "hover", "normal", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, clear)
		var target: String = id
		b.set_meta("area_id", id)
		b.pressed.connect(func() -> void: travel_requested.emit(target))
		b.focus_entered.connect(func() -> void:
			_selected = target
			queue_redraw())
		add_child(b)
		MenuNav.hover_selects(b)
		buttons.append(b)

	await get_tree().process_frame
	queue_redraw()

## Lay the rooms out on a grid.
##
## map_position is authored in loose units that read fine as dots and overlap badly as
## boxes, so it is snapped to a grid and collisions are resolved by pushing right. Without
## that a long street quietly sits on top of its neighbour and the map reads as one room.
func _place_rooms(ids: Array[String]) -> void:
	var cells: Dictionary = {}          # Vector2i -> area id
	var placed: Dictionary = {}         # area id -> [gx, gy, w]
	var order := ids.duplicate()
	order.sort_custom(func(a: String, b: String) -> bool:
		var pa: Vector2 = ContentDB.areas[a].map_position
		var pb: Vector2 = ContentDB.areas[b].map_position
		if is_equal_approx(pa.y, pb.y):
			return pa.x < pb.x
		return pa.y < pb.y)

	for id in order:
		var mp: Vector2 = ContentDB.areas[id].map_position
		var w: int = clampi(int(round(_street_length(id) / PX_PER_CELL)), 1, 3)
		var gx := int(round(mp.x * 2.0))
		var gy := int(round(mp.y * 2.0))
		var guard := 0
		while _occupied(cells, gx, gy, w) and guard < 64:
			gx += 1
			guard += 1
		for i in range(w):
			cells[Vector2i(gx + i, gy)] = id
		placed[id] = [gx, gy, w]

	var lo := Vector2i(9999, 9999)
	for id in placed.keys():
		lo.x = mini(lo.x, placed[id][0])
		lo.y = mini(lo.y, placed[id][1])
	for id in placed.keys():
		var gx: int = placed[id][0] - lo.x
		var gy: int = placed[id][1] - lo.y
		var w: int = placed[id][2]
		_rooms[id] = Rect2(
			Vector2(gx * CELL.x, gy * CELL.y),
			Vector2(w * CELL.x - GAP, CELL.y - GAP))

func _occupied(cells: Dictionary, gx: int, gy: int, w: int) -> bool:
	for i in range(w):
		if cells.has(Vector2i(gx + i, gy)):
			return true
	return false

## Shrink the whole map to fit the panel, whatever the city grows into.
func _fit_to_panel() -> void:
	var used := Rect2()
	var first := true
	for id in _rooms.keys():
		var r: Rect2 = _rooms[id]
		used = r if first else used.merge(r)
		first = false
	if used.size.x <= 0.0 or used.size.y <= 0.0:
		return
	var inner := size - PAD * 2.0
	if inner.x <= 0.0 or inner.y <= 0.0:
		inner = Vector2(300.0, 110.0)
	var s: float = minf(minf(inner.x / used.size.x, inner.y / used.size.y), 1.0)
	var offset := PAD + (inner - used.size * s) * 0.5 - used.position * s
	for id in _rooms.keys():
		var r: Rect2 = _rooms[id]
		_rooms[id] = Rect2(r.position * s + offset, r.size * s)

## The real length of a street, straight out of the layout the game builds from.
func _street_length(id: String) -> float:
	var layout := _layout(id)
	return float(layout.get("walk_max_x", 800.0)) - float(layout.get("walk_min_x", 0.0))

static func _layout(area_id: String) -> Dictionary:
	if _layouts.has(area_id):
		return _layouts[area_id]
	var path := "res://data/areas/%s.json" % area_id
	var out: Dictionary = {}
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Dictionary:
			out = parsed
	_layouts[area_id] = out
	return out

func _visited(id: String) -> bool:
	return id == _current or bool(GameManager.get_flag("visited_" + id, false))

## A room you have not been to that somewhere you have been opens onto. You get the outline
## and the join, and no name: there is a way on from here, and that is all you have earned.
func _known(id: String) -> bool:
	if _visited(id):
		return true
	for other in ContentDB.areas.keys():
		if not _visited(str(other)):
			continue
		if id in ContentDB.areas[other].connections:
			return true
	return false

## A stable hue per district, so a district reads as one place. Derived rather than kept in
## a table here, which would go stale the first time somebody adds a district.
func _district_color(id: String) -> Color:
	var d: String = ContentDB.areas[id].district
	if d == "":
		return Color(0.55, 0.52, 0.62)
	return Color.from_hsv(float(absi(hash(d)) % 997) / 997.0, 0.40, 0.80)

## Where a line from the centre of `r` towards `target` crosses the room wall.
##
## The slab method: how far along the direction each axis lets you travel before leaving the
## box, and the nearer of the two is the wall you actually go through.
func _wall_point(r: Rect2, target: Vector2) -> Vector2:
	var c := r.get_center()
	var d := target - c
	if d.length() < 0.001:
		return c
	d = d.normalized()
	var h := r.size * 0.5
	var tx: float = (h.x / absf(d.x)) if absf(d.x) > 0.0001 else INF
	var ty: float = (h.y / absf(d.y)) if absf(d.y) > 0.0001 else INF
	return c + d * minf(tx, ty)

func _draw() -> void:
	# Joins are corridors between walls, never lines between centres. Drawing centre to
	# centre put a diagonal straight across the middle of every room it passed, so the map
	# read as scribble laid over boxes instead of as somewhere you could walk.
	for id in _rooms.keys():
		var a := str(id)
		for to in ContentDB.areas[a].connections:
			var b := str(to)
			if not _rooms.has(b) or a >= b:
				continue
			if not (_visited(a) or _visited(b)):
				continue
			var open: bool = _visited(a) and _visited(b)
			var col: Color = UITheme.ACCENT_2 if open else Color(0.40, 0.38, 0.48)
			var ca: Vector2 = _rooms[a].get_center()
			var cb: Vector2 = _rooms[b].get_center()
			var pa := _wall_point(_rooms[a], cb)
			var pb := _wall_point(_rooms[b], ca)
			if pa.distance_to(pb) > 1.5:
				draw_line(pa, pb, col, 2.0 if open else 1.0)
			# The doorway itself: a short bar lying along the wall it is cut into.
			for pair in [[pa, _rooms[a]], [pb, _rooms[b]]]:
				var pt: Vector2 = pair[0]
				var rr: Rect2 = pair[1]
				var along := Vector2(0, 1) if (absf(pt.x - rr.position.x) < 0.5
					or absf(pt.x - rr.end.x) < 0.5) else Vector2(1, 0)
				draw_line(pt - along * 3.0, pt + along * 3.0, col, 2.0)

	for id in _rooms.keys():
		var aid := str(id)
		if not _known(aid):
			continue
		var r: Rect2 = _rooms[aid]
		if _visited(aid):
			var col := _district_color(aid)
			draw_rect(r, Color(col.r, col.g, col.b, 0.34), true)
			draw_rect(r, col, false, 1.0)
		else:
			# Somewhere the city goes that you have not been.
			draw_rect(r, Color(0.09, 0.08, 0.12, 0.7), true)
			draw_rect(r, Color(0.42, 0.40, 0.50), false, 1.0)

	# Selection, then current, so where you are always wins the overlap.
	if _selected != "" and _selected != _current and _rooms.has(_selected):
		draw_rect(_rooms[_selected].grow(1.5), UITheme.ACCENT_2, false, 1.0)
	if _rooms.has(_current):
		var r: Rect2 = _rooms[_current]
		draw_rect(r, Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.42), true)
		draw_rect(r.grow(1.0), UITheme.ACCENT, false, 2.0)

	# Name the current room and whatever is selected, and nothing else. Naming twelve rooms
	# at this size is what made the earliest version unreadable.
	var font := get_theme_default_font()
	var fs := 8
	for id in [_current, _selected]:
		var sid := str(id)
		if sid == "" or not _rooms.has(sid) or not _visited(sid):
			continue
		var text: String = ContentDB.areas[sid].display_name
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var room: Rect2 = _rooms[sid]
		var at := Vector2(room.get_center().x - w * 0.5, room.position.y - 2.0)
		at.x = clampf(at.x, 1.0, maxf(1.0, size.x - w - 1.0))
		at.y = maxf(at.y, fs + 1.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3,
			Color(0.04, 0.03, 0.07))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			UITheme.ACCENT if sid == _current else UITheme.ACCENT_2)

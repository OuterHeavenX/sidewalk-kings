class_name MapView
extends Control
## The map of Riverbend, drawn from the real connection graph.
##
## It used to be a list of area names, which told you nothing a list of area names does
## not already tell you: not which places join to which, not where you are in relation to
## anywhere else, not how far the city extends past what you have seen.
##
## Nodes come from AreaData.map_position and edges from AreaData.connections, so the map
## cannot disagree with the world. Somewhere you have not been is drawn as an unmarked
## node with no name, because knowing a place exists and not knowing what it is is more
## useful than not knowing it exists.

signal travel_requested(area_id: String)

const PAD := Vector2(18.0, 14.0)
const NODE := 5.0

var buttons: Array[Button] = []

var _points: Dictionary = {}      # area id -> Vector2 in local space
var _edges: Array = []            # [from_id, to_id]
var _current: String = ""
var _selected: String = ""

func build(current_area: String, can_travel: bool) -> void:
	_current = current_area
	for c in get_children():
		c.queue_free()
	buttons.clear()
	_points.clear()
	_edges.clear()

	var ids: Array[String] = []
	for id in ContentDB.areas.keys():
		ids.append(str(id))
	ids.sort()
	if ids.is_empty():
		return

	# Fit the whole city into the panel, whatever coordinates the areas were authored in.
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for id in ids:
		var mp: Vector2 = ContentDB.areas[id].map_position
		lo = Vector2(minf(lo.x, mp.x), minf(lo.y, mp.y))
		hi = Vector2(maxf(hi.x, mp.x), maxf(hi.y, mp.y))
	var span := Vector2(maxf(hi.x - lo.x, 0.001), maxf(hi.y - lo.y, 0.001))
	var inner := size - PAD * 2.0
	if inner.x <= 0.0 or inner.y <= 0.0:
		inner = Vector2(240.0, 96.0)

	for id in ids:
		var mp: Vector2 = ContentDB.areas[id].map_position
		_points[id] = PAD + Vector2(
			(mp.x - lo.x) / span.x * inner.x,
			(mp.y - lo.y) / span.y * inner.y)

	var seen: Dictionary = {}
	for id in ids:
		for to in ContentDB.areas[id].connections:
			var key: String = id + "|" + str(to) if id < str(to) else str(to) + "|" + id
			if seen.has(key) or not _points.has(str(to)):
				continue
			seen[key] = true
			_edges.append([id, str(to)])

	for id in ids:
		if not _visited(id):
			continue
		# A compact hit target on the node itself. Full-size labelled buttons were tried
		# first and nine of them simply do not fit a map this size: they overlapped each
		# other and hid the graph they were supposed to describe. The name is drawn for
		# whichever node is selected instead, which is the only one you need named.
		var b := Button.new()
		b.text = ""
		b.tooltip_text = "%s  —  %s" % [ContentDB.areas[id].display_name, ContentDB.areas[id].district]
		b.custom_minimum_size = Vector2(NODE * 2.0 + 6.0, NODE * 2.0 + 6.0)
		b.size = b.custom_minimum_size
		b.position = _points[id] - b.size * 0.5
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		# The default focus box is a square and every node is a circle, so the selection
		# ring is drawn in _draw() instead and the button itself stays invisible.
		var clear := UITheme.panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0)
		for st in ["focus", "hover", "normal", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, clear)
		b.disabled = (id == _current) or not can_travel
		var target: String = id
		b.set_meta("area_id", id)
		b.pressed.connect(func() -> void: travel_requested.emit(target))
		b.focus_entered.connect(func() -> void:
			_selected = target
			queue_redraw())
		add_child(b)
		MenuNav.hover_selects(b)
		if not b.disabled:
			buttons.append(b)

	await get_tree().process_frame
	queue_redraw()

func _visited(id: String) -> bool:
	return id == _current or bool(GameManager.get_flag("visited_" + id, false))

func _draw() -> void:
	# Edges first, so the nodes sit on top of them.
	for e in _edges:
		var a: String = e[0]
		var b: String = e[1]
		var known: bool = _visited(a) and _visited(b)
		draw_line(_points[a], _points[b],
			UITheme.BORDER if known else Color(0.24, 0.22, 0.30), 1.0)
	for id in _points.keys():
		var p: Vector2 = _points[id]
		if id == _current:
			draw_circle(p, NODE + 2.0, UITheme.ACCENT)
			draw_circle(p, NODE, UITheme.PANEL)
		elif _visited(str(id)):
			draw_circle(p, NODE, UITheme.ACCENT_2)
		else:
			# Somewhere the city goes that you have not been.
			draw_arc(p, NODE - 1.0, 0.0, TAU, 10, Color(0.42, 0.38, 0.50), 1.0)

	# The selection ring, drawn round because the nodes are round.
	if _selected != "" and _selected != _current and _points.has(_selected):
		draw_arc(_points[_selected], NODE + 3.0, 0.0, TAU, 20, UITheme.ACCENT_2, 1.0)

	# Name only what matters: where you are, and what you have selected. Naming everything
	# is what made the first version unreadable.
	var font := get_theme_default_font()
	var fs := 8
	for id in [_current, _selected]:
		var sid := str(id)
		if sid == "" or not _points.has(sid) or not _visited(sid):
			continue
		var a: AreaData = ContentDB.areas[sid]
		var text: String = a.display_name
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at: Vector2 = _points[sid] + Vector2(-w * 0.5, -NODE - 4.0)
		at.x = clampf(at.x, 1.0, maxf(1.0, size.x - w - 1.0))
		at.y = maxf(at.y, fs + 1.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3,
			Color(0.04, 0.03, 0.07))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			UITheme.ACCENT if sid == _current else UITheme.ACCENT_2)

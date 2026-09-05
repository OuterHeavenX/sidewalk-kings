class_name Ambient
extends Node
## The small movement that stops a street looking like a photograph.
##
## Nothing here touches gameplay. No collision, no damage, no state. It exists because a
## perfectly lit still frame still reads as dead, and the cheapest fix for that is having
## a few things in shot that are not holding perfectly still.
##
## One node per area drives every effect from a single _process, rather than giving each
## swaying awning its own script. A street has a couple of dozen of these and they are all
## doing arithmetic on one float.
##
## Everything is integer-pixel. The project snaps 2D transforms to the pixel grid, so a
## sub-pixel sway would not render smoothly, it would judder between two positions at an
## uneven rate. A one or two pixel step at a slow rate reads as a breeze; anything smaller
## reads as a fault.

const DRIFT_MARGIN := 40.0

var _sways: Array[Dictionary] = []
var _flickers: Array[Dictionary] = []
var _drifters: Array[Dictionary] = []
var _t: float = 0.0
var _area_min_x: float = 0.0
var _area_max_x: float = 800.0

func setup(min_x: float, max_x: float) -> void:
	_area_min_x = min_x
	_area_max_x = max_x

## A hanging or soft object that moves with the air: washing, an awning, an aerial.
func add_sway(node: Node2D, pixels: int, speed: float) -> void:
	if node == null or pixels <= 0:
		return
	_sways.append({
		"node": node,
		"base_x": node.position.x,
		"amount": pixels,
		"speed": maxf(0.05, speed),
		# Everything swaying in step looks mechanical, so each starts somewhere different.
		"phase": randf() * TAU,
	})

## A light source that is not perfectly steady: a failing tube, a neon sign, a screen.
## Modulate is inherited by children, so this carries the emission overlay with it and the
## bloom pulses along with the sprite.
func add_flicker(node: CanvasItem, amount: float, speed: float) -> void:
	if node == null or amount <= 0.0:
		return
	_flickers.append({
		"node": node,
		"base": node.modulate,
		"amount": clampf(amount, 0.0, 0.9),
		"speed": maxf(0.05, speed),
		"phase": randf() * TAU,
		"seed": randf() * 100.0,
	})

## Litter, leaves, paper: a few motes crossing the street on the wind.
func add_drift(parent: Node2D, count: int, speed: float, colours: Array, y_min: float, y_max: float) -> void:
	if count <= 0 or colours.is_empty():
		return
	for i in count:
		var s := Sprite2D.new()
		s.texture = _mote_texture(_to_colour(colours[i % colours.size()]))
		s.centered = false
		s.z_index = -6
		s.position = Vector2(
			randf_range(_area_min_x - DRIFT_MARGIN, _area_max_x + DRIFT_MARGIN),
			randf_range(y_min, y_max))
		parent.add_child(s)
		_drifters.append({
			"node": s,
			"speed": speed * randf_range(0.7, 1.4),
			"bob": randf_range(0.6, 1.6),
			"phase": randf() * TAU,
			"base_y": s.position.y,
		})

func _mote_texture(c: Color) -> ImageTexture:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(c)
	img.set_pixel(1, 1, Color(c.r, c.g, c.b, 0.0))
	return ImageTexture.create_from_image(img)

func _to_colour(v: Variant) -> Color:
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else 1.0)
	return Color(0.8, 0.8, 0.8, 1.0)

func count() -> int:
	return _sways.size() + _flickers.size() + _drifters.size()

func _process(delta: float) -> void:
	if _sways.is_empty() and _flickers.is_empty() and _drifters.is_empty():
		return
	_t += delta

	for s in _sways:
		var n: Node2D = s["node"]
		if not is_instance_valid(n):
			continue
		# Rounded, so the sprite lands on whole pixels instead of shimmering between two.
		var off := roundi(sin(_t * float(s["speed"]) + float(s["phase"])) * float(s["amount"]))
		n.position.x = float(s["base_x"]) + float(off)

	for f in _flickers:
		var c: CanvasItem = f["node"]
		if not is_instance_valid(c):
			continue
		# Two waves at unrelated rates, so it never settles into an obvious loop.
		var p: float = float(f["phase"])
		var sp: float = float(f["speed"])
		var wobble: float = sin(_t * sp + p) * 0.6 + sin(_t * sp * 2.7 + p * 1.9) * 0.4
		var k: float = 1.0 + wobble * float(f["amount"])
		var base: Color = f["base"]
		c.modulate = Color(base.r * k, base.g * k, base.b * k, base.a)

	for dft in _drifters:
		var n2: Node2D = dft["node"]
		if not is_instance_valid(n2):
			continue
		n2.position.x += float(dft["speed"]) * delta
		n2.position.y = float(dft["base_y"]) + roundi(sin(_t * float(dft["bob"]) + float(dft["phase"])) * 2.0)
		if n2.position.x > _area_max_x + DRIFT_MARGIN:
			n2.position.x = _area_min_x - DRIFT_MARGIN
		elif n2.position.x < _area_min_x - DRIFT_MARGIN:
			n2.position.x = _area_max_x + DRIFT_MARGIN

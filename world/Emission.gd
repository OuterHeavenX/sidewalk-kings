class_name Emission
extends RefCounted
## Glow overlays for sprites that emit light.
##
## Bloom is a property of the finished frame, not of a sprite: Godot blooms whatever is
## brighter than the environment's threshold. With HDR 2D on and the threshold at 1.0,
## ordinary art clamps at 1.0 and can never bloom, however pale it is. Only something
## pushed ABOVE 1.0 bleeds.
##
## So a glowing lamp is two sprites: the normal art, plus a mask holding only the lamp
## glass, drawn on top at a gain above 1.0. The masks come from tools/gen_emission.py,
## which derives them from the art itself rather than anyone hand-painting them.

const DIR := "res://assets/art/emission/"
const GAINS_PATH := DIR + "gains.json"
const DEFAULT_GAIN := 2.0

## A dark area multiplies every canvas item, emission overlays included, so a lamp that
## reads as 2.0 in daylight would fall to 0.6 under a night tint and stop blooming
## entirely. Area lighting sets this to 1/ambient so light sources stay light sources.
static var boost: float = 1.0

## Overlays are only meaningful when the area is lit and bloom is on. Attached anywhere
## else they render at their raw gain, clamp to white, and blow the asset out: a metro
## sign becomes a white rectangle. Areas with no lighting block, and every area when the
## player has lighting turned off, must build exactly as they did before this existed.
static var enabled: bool = false

static var _gains: Dictionary = {}
static var _loaded: bool = false

static func _load_gains() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(GAINS_PATH):
		return
	var f := FileAccess.open(GAINS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_gains = parsed

static func has_mask(asset: String) -> bool:
	return asset != "" and ResourceLoader.exists(DIR + asset + "_e.png")

static func gain_for(asset: String) -> float:
	_load_gains()
	return float(_gains.get(asset, DEFAULT_GAIN))

## Add a glow overlay to `host`, matching an existing sprite's placement. Returns null when
## the asset has no mask, which is the normal case for most art.
static func attach(host: Node2D, asset: String, like: Sprite2D = null, z_offset: int = 1) -> Sprite2D:
	if not enabled or not has_mask(asset):
		return null
	var tex: Texture2D = load(DIR + asset + "_e.png")
	if tex == null:
		return null
	var s := Sprite2D.new()
	s.name = "Emission"
	s.texture = tex
	s.centered = like.centered if like else false
	s.offset = like.offset if like else Vector2.ZERO
	s.flip_h = like.flip_h if like else false
	s.position = Vector2.ZERO
	s.z_index = z_offset
	# The overlay must not be lit by 2D lights: it IS the light. Without this a lamp head
	# would darken in its own shadow, which looks exactly as wrong as it sounds.
	s.light_mask = 0
	var g := gain_for(asset) * boost
	s.modulate = Color(g, g, g, 1.0)
	host.add_child(s)
	return s

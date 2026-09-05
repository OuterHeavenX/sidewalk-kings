class_name AreaLighting
extends Node2D
## Per-area lighting, built from the `lighting` block of an area layout.
##
## Three parts, all optional and all data:
##   ambient  - a CanvasModulate tint. This is the time of day.
##   lights   - PointLight2D pools. Lamps, shop windows, a tunnel mouth.
##   glow     - whether this area's emissive art is allowed to bloom.
##
## An area with no `lighting` block builds nothing and looks exactly as it did before, so
## this rolls out one street at a time instead of all at once.

const LIGHT_DIR := "res://assets/art/light/"
const DEFAULT_TEX := "lamp"

var enabled: bool = false
var ambient: Color = Color.WHITE
var glow_wanted: bool = false

var _modulate_node: CanvasModulate = null
var _lights: Array[PointLight2D] = []

## Quality is a user setting, because lights and bloom cost fill rate and the weakest
## target here is a phone. Off means the area builds unlit, exactly like before.
static func quality_enabled() -> bool:
	return GameManager.lighting_enabled

func build(layout: Dictionary) -> void:
	var cfg: Dictionary = layout.get("lighting", {})
	if cfg.is_empty():
		return
	enabled = true
	glow_wanted = bool(cfg.get("glow", true))
	ambient = _colour(cfg.get("ambient", [1, 1, 1]), Color.WHITE)

	if not quality_enabled():
		# Still report as enabled so the area's intent is inspectable, but draw nothing.
		Emission.boost = 1.0
		return

	_modulate_node = CanvasModulate.new()
	_modulate_node.name = "Ambient"
	_modulate_node.color = ambient
	add_child(_modulate_node)

	# Compensate emission for the ambient tint so lamps stay above the bloom threshold
	# however dark the night is. Without this, turning the lights down turns them off.
	var lum: float = maxf((ambient.r + ambient.g + ambient.b) / 3.0, 0.2)
	Emission.boost = 1.0 / lum

	for entry in cfg.get("lights", []):
		_add_light(entry)

func _add_light(entry: Dictionary) -> void:
	var tex_name := str(entry.get("texture", DEFAULT_TEX))
	var path := LIGHT_DIR + tex_name + ".png"
	if not ResourceLoader.exists(path):
		push_warning("[AreaLighting] no light texture '%s'" % tex_name)
		return
	var l := PointLight2D.new()
	l.texture = load(path)
	l.position = Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)))
	l.color = _colour(entry.get("color", [1, 1, 1]), Color.WHITE)
	l.energy = float(entry.get("energy", 1.0))
	l.texture_scale = float(entry.get("scale", 1.0))
	l.blend_mode = Light2D.BLEND_MODE_ADD
	# Lights sit under everything they illuminate; z only matters for the editor view.
	l.z_index = 0
	add_child(l)
	_lights.append(l)

func light_count() -> int:
	return _lights.size()

func _colour(v: Variant, fallback: Color) -> Color:
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else 1.0)
	return fallback

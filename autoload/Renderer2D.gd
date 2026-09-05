extends Node
## Owns the one WorldEnvironment the game has, and the bloom settings on it.
##
## Why a threshold of exactly 1.0: with HDR 2D enabled, ordinary art clamps at 1.0, so
## nothing painted can ever bloom by accident no matter how pale it is. Only sprites
## deliberately pushed above 1.0 bleed, which is what Emission does. That separation is
## the whole reason bloom is safe to use on a 480x270 frame. Without it the threshold
## becomes a fight against every white sneaker and lit window in the art, and the result
## is the smeared, vaseline look that gives pixel-art bloom a bad name.
##
## Verified working on the Compatibility renderer in a real browser, which is the only
## renderer this game ships. Glow is unsupported on Compatibility in Godot 4.0 to 4.2, so
## this needs 4.3 or newer.

var env: Environment = null
var _world: WorldEnvironment = null
var _glow_on: bool = false

const THRESHOLD := 1.0
const INTENSITY := 1.15
const STRENGTH := 1.05
const BLOOM := 0.05

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = false
	env.glow_intensity = INTENSITY
	env.glow_strength = STRENGTH
	env.glow_bloom = BLOOM
	env.glow_hdr_threshold = THRESHOLD
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	# Bias the blur toward the wider taps: a tight glow on a 480x270 frame just makes
	# bright pixels look chunky, where a wide one reads as light in air.
	env.set_glow_level(1, 0.0)
	env.set_glow_level(2, 0.6)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.7)
	env.set_glow_level(5, 0.3)
	_world = WorldEnvironment.new()
	_world.name = "GameEnvironment"
	_world.environment = env
	add_child(_world)
	_apply_hdr()

func _apply_hdr() -> void:
	var vp := get_viewport()
	if vp:
		vp.use_hdr_2d = true

## Called by each area as it builds. Areas with no lighting block render exactly as they
## did before this system existed.
func apply_area_glow(on: bool) -> void:
	_glow_on = on
	if env:
		env.glow_enabled = on
	_apply_hdr()

func is_glow_on() -> bool:
	return _glow_on

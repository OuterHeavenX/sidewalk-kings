extends Node2D
## Tiny floating health bar drawn above an enemy.

@export var width: float = 22.0
@export var height: float = 3.0

var max_value: float = 30.0
var value: float = 30.0
var _display: float = 30.0

func _ready() -> void:
	z_index = 40

func set_max(v: float) -> void:
	max_value = maxf(1.0, v)
	value = max_value
	_display = value
	queue_redraw()

func set_value(v: float) -> void:
	value = clampf(v, 0.0, max_value)
	queue_redraw()

func _process(delta: float) -> void:
	if absf(_display - value) > 0.05:
		_display = lerpf(_display, value, clampf(delta * 9.0, 0.0, 1.0))
		queue_redraw()

func _draw() -> void:
	var w := width
	var h := height
	var r := Rect2(-w * 0.5, 0, w, h)
	draw_rect(r.grow(1.0), Color(0.05, 0.04, 0.08, 0.85))
	draw_rect(r, Color(0.18, 0.16, 0.22, 0.9))
	var ratio := clampf(_display / max_value, 0.0, 1.0)
	var col := Color(0.87, 0.24, 0.24) if ratio > 0.35 else Color(1.0, 0.55, 0.2)
	draw_rect(Rect2(r.position, Vector2(w * ratio, h)), col)

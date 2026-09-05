class_name UITheme
extends RefCounted
## Shared palette and small helpers so every menu looks like the same game.

const BG        := Color(0.086, 0.075, 0.125)
const BG_SOFT   := Color(0.145, 0.125, 0.196)
const PANEL     := Color(0.176, 0.149, 0.243, 0.96)
const PANEL_DIM := Color(0.114, 0.098, 0.157, 0.94)
const BORDER    := Color(0.474, 0.416, 0.588)
const ACCENT    := Color(0.898, 0.302, 0.333)
const ACCENT_2  := Color(0.988, 0.769, 0.259)
const GOOD      := Color(0.443, 0.831, 0.494)
const BAD       := Color(0.914, 0.361, 0.361)
const TEXT      := Color(0.945, 0.933, 0.909)
const TEXT_DIM  := Color(0.663, 0.639, 0.706)
const HP        := Color(0.870, 0.243, 0.243)
const ENERGY    := Color(0.941, 0.769, 0.275)
const SPECIAL   := Color(0.784, 0.365, 0.894)
const XP        := Color(0.431, 0.745, 0.941)

static func panel_style(bg: Color = PANEL, border: Color = BORDER, width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

static func bar_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(1)
	return sb

## A 4px outline on a 9px glyph is nearly half its height: it closes the counters and
## turns small text into a dark smudge. 2 is enough to keep text legible over the street.
static func style_label(l: Label, size: int = 10, color: Color = TEXT, outline: int = 2) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.07, 1.0))
	l.add_theme_constant_override("outline_size", outline)

## Sliders had no focus state at all, so on a keyboard or a controller you could move onto
## a volume slider and get no indication whatsoever that it was the thing you were about to
## change. Buttons already highlight on focus; this gives sliders the same courtesy.
static func style_slider(sl: Range, row: Control = null) -> void:
	var target: Control = row if row != null else sl
	target.modulate = Color(1, 1, 1, 1)
	sl.focus_entered.connect(func() -> void:
		if is_instance_valid(target):
			target.modulate = ACCENT_2)
	sl.focus_exited.connect(func() -> void:
		if is_instance_valid(target):
			target.modulate = Color(1, 1, 1, 1))

static func style_button(b: Button, size: int = 12) -> void:
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", ACCENT_2)
	b.add_theme_color_override("font_focus_color", ACCENT_2)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	b.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.07, 1.0))
	b.add_theme_constant_override("outline_size", 2)
	var normal := panel_style(Color(0.15, 0.13, 0.21, 0.9), Color(0.35, 0.3, 0.45))
	var hover := panel_style(Color(0.26, 0.2, 0.34, 0.96), ACCENT_2)
	var pressed := panel_style(Color(0.34, 0.17, 0.22, 0.98), ACCENT)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", panel_style(Color(0.12, 0.11, 0.15, 0.8), Color(0.22, 0.2, 0.26)))

class_name MenuNav
extends RefCounted
## Shared keyboard, controller and mouse navigation for menus.
##
## Focus is the single source of truth. The menus each used to keep their own `index`
## alongside Godot's focus, and the two drifted apart the moment a mouse was involved:
## clicking one button left `index` pointing at another, so the item that looked selected
## and the item that Enter activated were different. Nothing errors, it just feels broken.
##
## Everything here works off whatever actually has focus, and hovering moves focus, so the
## mouse and the keyboard can never disagree about what is selected.

## Controls that can actually be selected right now: visible, focusable, not disabled.
static func focusables(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	_collect(root, out)
	return out

static func _collect(node: Node, out: Array[Control]) -> void:
	for child in node.get_children():
		var c := child as Control
		if c != null:
			if not c.is_visible_in_tree():
				continue
			if c.focus_mode != Control.FOCUS_NONE and not _is_disabled(c):
				out.append(c)
		_collect(child, out)

static func _is_disabled(c: Control) -> bool:
	if c is BaseButton:
		return (c as BaseButton).disabled
	return false

## Hovering selects. Without this the mouse and the keyboard maintain separate ideas of
## what is highlighted, which is the single biggest cause of a menu feeling unpredictable.
static func hover_selects(c: Control) -> void:
	if c.focus_mode == Control.FOCUS_NONE:
		return
	c.mouse_entered.connect(func() -> void:
		if is_instance_valid(c) and c.is_visible_in_tree() and not _is_disabled(c):
			c.grab_focus())

static func hover_selects_all(root: Node) -> void:
	for c in focusables(root):
		hover_selects(c)

## Move focus within `list`, wrapping. Returns false when there is nothing to move to.
static func step(list: Array[Control], dir: int, current: Control) -> bool:
	if list.is_empty():
		return false
	var at := list.find(current)
	var next_index := 0 if at < 0 else wrapi(at + dir, 0, list.size())
	list[next_index].grab_focus()
	return true

static func focus_first(list: Array[Control]) -> bool:
	if list.is_empty():
		return false
	list[0].grab_focus()
	return true

## True when Left/Right belong to the control itself rather than to menu navigation.
## A focused slider has to be adjustable, so it consumes the horizontal directions and the
## caller must offer another way out of that group.
static func takes_horizontal(c: Control) -> bool:
	return c is Range and not (c is ScrollBar)

## Activate whatever is focused. Buttons fire their pressed signal; anything else is left
## alone, so a focused slider is not accidentally "pressed".
static func activate(c: Control) -> bool:
	if c == null:
		return false
	if c is BaseButton:
		var b := c as BaseButton
		if b.disabled:
			return false
		if b.toggle_mode:
			b.button_pressed = not b.button_pressed
			b.toggled.emit(b.button_pressed)
		b.pressed.emit()
		return true
	return false

## Nudge a focused slider. Godot's own Range handling only reacts to the ui_* actions, and
## this game binds its own movement actions, so the two have to be joined up by hand.
static func nudge(c: Control, dir: int) -> bool:
	if not (c is Range):
		return false
	var r := c as Range
	var stepv: float = r.step if r.step > 0.0 else (r.max_value - r.min_value) / 10.0
	r.value = clampf(r.value + stepv * float(dir), r.min_value, r.max_value)
	return true

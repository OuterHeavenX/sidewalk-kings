extends Node
## What the player should be doing next, in words.
##
## The playthrough bot found that chapter one's progression depends on walking back to Dez
## between jobs, and that nothing in the game ever says so. That is not a bug a flag can
## fix. Somebody has to tell the player, so Dez does.
##
## Hints are an ordered list in `data/hints.json`, checked top to bottom, first match wins.
## The ordering is the design: the most specific state has to sit above the broader one it
## follows, or an early condition swallows every state after it. The final entry has no
## condition at all, so there is never a state in which Dez has nothing to say -- a hint
## system that can come up empty is worse than none, because it is silent exactly when the
## player is most lost.

const PATH := "res://data/hints.json"

var _hints: Array = []

func _ready() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_warning("[HintManager] no hints at %s" % PATH)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_hints = parsed.get("hints", [])
	print("[HintManager] %d hints" % _hints.size())

## The first hint whose conditions are met. Never empty while the data is present.
func current() -> Dictionary:
	for h in _hints:
		if _matches(h):
			return h
	return {}

func current_text() -> String:
	return str(current().get("text", ""))

## The area the current hint points at, for the map to mark. "" means "where you are".
func current_target() -> String:
	return str(current().get("where", ""))

func _matches(h: Dictionary) -> bool:
	var need := str(h.get("if_flag", ""))
	if need != "" and not GameManager.get_flag(need):
		return false
	var deny := str(h.get("if_not_flag", ""))
	if deny != "" and GameManager.get_flag(deny):
		return false
	var q := str(h.get("if_quest", ""))
	if q != "" and not QuestManager.is_active(q):
		return false
	return true

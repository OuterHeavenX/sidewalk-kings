extends Pickup
## Food / item dropped by enemies or hidden inside breakable objects.

var item_id: String = ""
var is_key_item: bool = false

func setup(id: String, from: Vector2, vel: Vector2, up: float, key_item: bool = false) -> void:
	item_id = id
	is_key_item = key_item
	launch(from, vel, up)
	call_deferred("_apply_icon")

func _apply_icon() -> void:
	if sprite == null:
		return
	var res := ContentDB.get_item(item_id)
	if res and res.get("icon") != null and res.get("icon") is Texture2D:
		sprite.texture = res.get("icon")
		return
	var fallback := "res://assets/art/ui/items/burger.png"
	if ResourceLoader.exists(fallback):
		sprite.texture = load(fallback)

func collect(by: Node) -> void:
	if collected:
		return
	collected = true
	var res := ContentDB.get_item(item_id)
	var name := str(res.get("display_name")) if res and res.get("display_name") != null else item_id.capitalize()
	if is_key_item:
		GameManager.add_key_item(item_id)
	else:
		GameManager.add_item(item_id, 1)
	AudioManager.play_sfx("pickup", -6.0)
	FX.number(name, global_position + Vector2(0, -18), Color(0.7, 1.0, 0.7), get_parent())
	GameManager.notify("Got %s" % name, "item")
	queue_free()

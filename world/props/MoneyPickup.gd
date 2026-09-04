extends Pickup
## Cash dropped by defeated enemies and smashed objects.

var amount: int = 5

func setup(value: int, from: Vector2, vel: Vector2, up: float) -> void:
	amount = maxi(1, value)
	launch(from, vel, up)
	call_deferred("_apply_icon")

func _apply_icon() -> void:
	if sprite == null:
		return
	var path := "res://assets/art/ui/items/coin_small.png"
	if amount >= 15:
		path = "res://assets/art/ui/items/bill.png"
	elif amount >= 8:
		path = "res://assets/art/ui/items/coin_big.png"
	if ResourceLoader.exists(path):
		sprite.texture = load(path)

func collect(by: Node) -> void:
	if collected:
		return
	collected = true
	GameManager.add_money(amount)
	AudioManager.play_sfx("money", -8.0, 0.14, 40)
	FX.number("+$%d" % amount, global_position + Vector2(0, -18), Color(1, 0.88, 0.4), get_parent())
	queue_free()

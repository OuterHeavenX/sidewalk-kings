class_name AreaData
extends Resource
## Metadata about a playable area for the map/menus. Scenes live in res://world/areas/<id>.tscn.

@export var id: String = ""
@export var display_name: String = "Somewhere"
@export var district: String = ""
@export var music: String = "street"
@export var ambience: String = "city"
@export var gang: String = ""
@export var map_position: Vector2 = Vector2.ZERO
@export var connections: Array[String] = []
@export_multiline var description: String = ""

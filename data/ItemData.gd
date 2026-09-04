class_name ItemData
extends Resource
## Generic inventory item: consumables, key items, cosmetics.

enum Kind { CONSUMABLE, KEY, BOOK, EQUIPMENT, MISC }

@export var id: String = ""
@export var display_name: String = "Item"
@export_multiline var description: String = ""
@export var kind: Kind = Kind.CONSUMABLE
@export var price: int = 10
@export var icon: Texture2D
@export var heal: int = 0
@export var energy: int = 0
@export var stackable: bool = true
@export var usable_in_field: bool = true
@export var flag_on_use: String = ""

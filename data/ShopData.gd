class_name ShopData
extends Resource
## Data-driven shop inventory. One ShopController handles every shop type.

enum ShopType { RESTAURANT, STORE, DOJO, BOOKS, WEAPONS, CLOTHING }

@export var id: String = ""
@export var display_name: String = "Shop"
@export var shop_type: ShopType = ShopType.STORE
@export var owner_name: String = "Owner"
@export var owner_portrait: Texture2D
@export var greeting: String = "Welcome."
@export var farewell: String = "Come back soon."
@export var broke_line: String = "You can't afford that."
@export var purchase_lines: Array[String] = ["Nice choice."]
## Item ids: FoodData / ItemData / BookData / WeaponData / MoveData ids depending on shop_type.
@export var inventory: Array[String] = []
@export var music: String = ""

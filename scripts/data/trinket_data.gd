class_name TrinketData
extends Resource
## An activated ability: use once per turn (see GameRules.TRINKET_LIMIT).
## Upgrading moves it to the next entry in `levels`.

@export var id: StringName
@export var display_name: String = "New Trinket"
@export var cost: int = 4
@export var levels: Array[TrinketLevel] = []
@export_multiline var description: String = ""
@export var icon: Texture2D

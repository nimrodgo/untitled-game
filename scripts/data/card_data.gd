class_name CardData
extends Resource
## A card definition. Design new cards by creating .tres files of this type.

@export var id: StringName
@export var display_name: String = "New Card"
@export var cost: int = 1
## Instant cards are free actions: playing them doesn't end your turn.
@export var instant: bool = false
@export var on_play: Array[Effect] = []
## Resolves once, when the card is bought.
@export var on_buy: Array[Effect] = []
@export_multiline var flavor_text: String = ""
@export var art: Texture2D
@export var tags: PackedStringArray = []

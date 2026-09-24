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
## Text shown on the card. Leave empty to auto-generate from the effects.
## Supports BBCode ([i], [b], [color]...), the icons 🪙 🂠 🗲, and live values in
## braces, e.g. {cards_drawn_this_turn} (see Encounter.text_vars()).
@export_multiline var on_play_text: String = ""
@export_multiline var on_buy_text: String = ""
@export_multiline var flavor_text: String = ""
@export var art: Texture2D
@export var tags: PackedStringArray = []


func get_play_text(vars: Dictionary = {}) -> String:
	var t := on_play_text if on_play_text != "" else Effect.describe_list(on_play)
	return t.format(vars)


func get_buy_text(vars: Dictionary = {}) -> String:
	var t := on_buy_text if on_buy_text != "" else Effect.describe_list(on_buy)
	return t.format(vars)


## True when the designer wrote the text (so we don't add our own labels like INSTANT).
func has_custom_text() -> bool:
	return on_play_text != "" or on_buy_text != ""

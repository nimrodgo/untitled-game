class_name CardData
extends Resource
## A card definition. Design new cards by creating .tres files of this type.

@export var id: StringName
@export var display_name: String = "New Card"
@export var cost: int = 1
## Instant cards are free actions: playing them doesn't end your turn.
@export var instant: bool = false
## Unplayable cards (most curses) stay in your hand as dead weight.
@export var playable: bool = true
@export var on_play: Array[Effect] = []
## Resolves once, when the card is bought.
@export var on_buy: Array[Effect] = []
## Text shown on the card. Leave empty to auto-generate from the effects.
## Supports BBCode ([i], [b], [color]...), the icons 🪙 🂠 🗲, and live values in
## braces, e.g. {cards_drawn_this_turn} (see Encounter.text_vars()).
@export_multiline var on_play_text: String = ""
@export_multiline var on_buy_text: String = ""
@export_multiline var flavor_text: String = ""
## Resolves when an effect discards this card (not the end-of-round cleanup).
@export var on_discard: Array[Effect] = []
## Resolves when this card is destroyed.
@export var on_destroy: Array[Effect] = []
## Resolves at the end of your turn if this card is still in your hand.
@export var on_turn_end_in_hand: Array[Effect] = []

@export_group("Curse")
## Curses are shown differently and can be targeted by "curse" effects.
@export var curse: bool = false
## Permanent curses stay in your deck between encounters (others vanish).
@export var permanent: bool = false
@export_group("")

## Which set this belongs to (see CardSets). One set per card/item/trinket.
@export var card_set: CardSets.Id = CardSets.Id.NONE
@export var art: Texture2D
@export var tags: PackedStringArray = []


func get_play_text(vars: Dictionary = {}) -> String:
	var t := on_play_text
	if t == "":
		var parts: PackedStringArray = []
		if not playable:
			parts.append("Unplayable")
		if not on_play.is_empty():
			parts.append(Effect.describe_list(on_play))
		if not on_discard.is_empty():
			parts.append("When discarded: " + Effect.describe_list(on_discard))
		if not on_destroy.is_empty():
			parts.append("When destroyed: " + Effect.describe_list(on_destroy))
		if not on_turn_end_in_hand.is_empty():
			parts.append("At the end of your turn, if in hand: " + Effect.describe_list(on_turn_end_in_hand))
		if permanent:
			parts.append("Permanent")
		t = ". ".join(parts)
	return t.format(vars)


func get_buy_text(vars: Dictionary = {}) -> String:
	var t := on_buy_text if on_buy_text != "" else Effect.describe_list(on_buy)
	return t.format(vars)


## True when the designer wrote the text (so we don't add our own labels like INSTANT).
func has_custom_text() -> bool:
	return on_play_text != "" or on_buy_text != ""

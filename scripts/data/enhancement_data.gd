class_name EnhancementData
extends Resource
## A shop upgrade applied to one card in your hand (permanently, for the run).
## Sold by the encounters that list its `card_set` (see EncounterData.card_sets).

@export var id: StringName
@export var display_name: String = "New Enhancement"
@export var cost: int = 2
## Which set this belongs to (see CardSets). One set per card/item/trinket/enhancement.
@export var card_set: CardSets.Id = CardSets.Id.NONE
@export var make_instant: bool = false
@export var extra_on_play: Array[Effect] = []
## Resolves when an effect discards the card (not the end-of-round cleanup).
@export var on_discard: Array[Effect] = []
## The card stays in your hand at the end of every turn.
@export var retain: bool = false
## After its effects resolve, the card is destroyed (permanently) instead of going to the discard pile.
@export var destroy_on_play: bool = false
## The card counts as a curse for everything that looks at curses.
@export var counts_as_curse: bool = false
## Text for the shop tile and appended to the card. Leave empty to auto-generate.
@export_multiline var description: String = ""


func get_description() -> String:
	if description != "":
		return description
	var parts: PackedStringArray = []
	if make_instant:
		parts.append("Card becomes Instant")
	if not extra_on_play.is_empty():
		parts.append("On play: " + Effect.describe_list(extra_on_play))
	if not on_discard.is_empty():
		parts.append("When discarded: " + Effect.describe_list(on_discard))
	if retain:
		parts.append("Retained")
	if destroy_on_play:
		parts.append("Destroyed when played")
	if counts_as_curse:
		parts.append("Counts as a curse")
	return ". ".join(parts)


## What this adds to a card's own text.
func card_text() -> String:
	if description != "":
		return description
	if extra_on_play.is_empty() and on_discard.is_empty() and not retain \
			and not destroy_on_play and not counts_as_curse:
		return ""   # make_instant only: the card already shows the instant icon
	return get_description()

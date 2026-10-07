class_name EnhancementData
extends Resource
## A shop upgrade applied to one card in your hand (permanently, for the run).
## A card holds at most ONE enhancement.
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
## Buying it destroys the chosen card (permanently) on the spot; the enhancement
## is not attached to anything.
@export var destroy_on_apply: bool = false
## The card counts as a curse for everything that looks at curses.
@export var counts_as_curse: bool = false
## Icon token (see Icons) shown in the corner of an enhanced card and on the
## shop tile. The card's own text is never changed by an enhancement.
@export var icon: String = ""
## Text for the shop tile and the hover legend. Leave empty to auto-generate.
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
	if destroy_on_apply:
		parts.append("Destroys the card immediately")
	if counts_as_curse:
		parts.append("Counts as a curse")
	return ". ".join(parts)

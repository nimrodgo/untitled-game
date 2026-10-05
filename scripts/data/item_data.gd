class_name ItemData
extends Resource
## A passive item. Bought as a free action; fires its effects on a trigger.

@export var id: StringName
@export var display_name: String = "New Item"
@export var cost: int = 3
@export var trigger: GameRules.Trigger = GameRules.Trigger.CARD_BOUGHT
@export var effects: Array[Effect] = []
## 0 = unlimited.
@export var limit_per_encounter: int = 0
## 0 = unlimited.
@export var limit_per_round: int = 0
@export_multiline var description: String = ""
@export var icon: Texture2D
## Passive: while you own this, every market card costs this much (-1 = off).
## The market shows the normal price struck through next to the new one.
@export var card_price_override: int = -1
## Which set this belongs to (see CardSets). One set per card/item/trinket.
@export var card_set: CardSets.Id = CardSets.Id.NONE


func get_description() -> String:
	if description != "":
		return description
	var when := ""
	match trigger:
		GameRules.Trigger.ENCOUNTER_START: when = "At encounter start"
		GameRules.Trigger.ROUND_START: when = "At round start"
		GameRules.Trigger.TURN_START: when = "At the start of your turn"
		GameRules.Trigger.BEFORE_CARD_BUY: when = "When you buy a card"
		GameRules.Trigger.CARD_BOUGHT: when = "After you buy a card"
		GameRules.Trigger.CARD_PLAYED: when = "When you play a card"
		GameRules.Trigger.ITEM_BOUGHT: when = "When you buy an item"
		GameRules.Trigger.TRINKET_USED: when = "When you use a trinket"
		GameRules.Trigger.OPPONENT_CARD_BOUGHT: when = "When your opponent buys a card"
		GameRules.Trigger.OPPONENT_CARD_PLAYED: when = "When your opponent plays a card"
		GameRules.Trigger.ROUND_END: when = "At the end of your turn"
		GameRules.Trigger.HAND_DRAWN: when = "At the start of your turn"
		GameRules.Trigger.CARD_DRAWN: when = "When you draw a card"
		GameRules.Trigger.CURSE_DRAWN: when = "When you draw a curse"
		GameRules.Trigger.CARD_DISCARDED: when = "When you discard a card"
		GameRules.Trigger.CARD_REMOVED: when = "When you remove a card"
		GameRules.Trigger.CARD_DESTROYED: when = "When you destroy a card"
		GameRules.Trigger.CARD_TRASHED_FROM_HAND: when = "When you remove or destroy a card in your hand"
	var limit := ""
	if limit_per_encounter == 1:
		limit = " (first time each encounter)"
	elif limit_per_encounter > 1:
		limit = " (%d times per encounter)" % limit_per_encounter
	elif limit_per_round == 1:
		limit = " (once per round)"
	elif limit_per_round > 1:
		limit = " (%d times per round)" % limit_per_round
	return "%s%s: %s" % [when, limit, Effect.describe_list(effects)]

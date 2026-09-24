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
		GameRules.Trigger.ROUND_END: when = "At round end"
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

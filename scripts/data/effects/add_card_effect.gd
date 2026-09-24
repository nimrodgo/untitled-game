class_name AddCardEffect
extends Effect
## Adds copies of a card to someone's cards (e.g. junk/status cards).

@export var card: CardData
@export var amount: int = 1
@export var zone: GameRules.Zone = GameRules.Zone.DRAW_SHUFFLE


func _init() -> void:
	target = GameRules.Target.OPPONENT


func apply(ctx: EffectContext) -> void:
	if card == null:
		return
	var who := ctx.resolve(target)
	for i in amount:
		ctx.encounter.add_card(who, card, zone)


func describe() -> String:
	var where := "deck"
	match zone:
		GameRules.Zone.HAND: where = "hand"
		GameRules.Zone.DISCARD: where = "discard"
		GameRules.Zone.DRAW_TOP: where = "deck (top)"
	var n := card.display_name if card else "?"
	return "%sAdd %d %s to %s" % [_who(), amount, n, where]


func ai_score() -> float:
	return 0.0

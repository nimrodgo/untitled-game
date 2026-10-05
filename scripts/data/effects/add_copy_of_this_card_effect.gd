class_name AddCopyOfThisCardEffect
extends Effect
## Adds a copy of the card this effect belongs to. The copy is the plain card:
## it does not inherit enhancements, so copy effects can't snowball.

@export var zone: GameRules.Zone = GameRules.Zone.DRAW_SHUFFLE


func apply(ctx: EffectContext) -> void:
	if ctx.card == null:
		return
	ctx.encounter.add_card(ctx.resolve(target), ctx.card.data, zone)


func describe() -> String:
	var where := "deck"
	match zone:
		GameRules.Zone.HAND: where = "hand"
		GameRules.Zone.DISCARD: where = "discard"
		GameRules.Zone.DRAW_TOP: where = "deck (top)"
	return "%sAdd a copy to your %s" % [_who(), where]


func ai_score() -> float:
	return 0.5

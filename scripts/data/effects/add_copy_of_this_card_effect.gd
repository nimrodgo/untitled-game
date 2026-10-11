class_name AddCopyOfThisCardEffect
extends Effect
## Adds a copy of the card this effect belongs to. The copy is the plain card:
## it does not inherit enhancements, so copy effects can't snowball.

@export var zone: GameRules.Zone = GameRules.Zone.DRAW_BOTTOM
## The copy is temporary (⏳).
@export var temporary: bool = false


func apply(ctx: EffectContext) -> void:
	if ctx.card == null:
		return
	await ctx.encounter.add_card(ctx.resolve(target), ctx.card.data, zone, temporary, ctx.owner)


func describe() -> String:
	var where := "deck (bottom)"
	match zone:
		GameRules.Zone.HAND: where = "hand"
		GameRules.Zone.DISCARD: where = "discard"
		GameRules.Zone.DRAW_TOP: where = "deck (top)"
	return "%sAdd a %scopy to your %s" % [_who(), "⏳ " if temporary else "", where]


func ai_score() -> float:
	return 0.5

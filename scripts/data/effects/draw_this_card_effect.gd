class_name DrawThisCardEffect
extends Effect
## Draw the card this effect belongs to (from wherever it is, e.g. the discard
## pile) into your hand. Does nothing while draws are locked.


func apply(ctx: EffectContext) -> void:
	if ctx.card == null:
		return
	await ctx.encounter.draw_specific(ctx.owner, ctx.card)


func describe() -> String:
	return "%s this card" % Icons.CARD


func ai_score() -> float:
	return 0.5

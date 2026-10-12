class_name PlayThisCardEffect
extends Effect
## Play the card this effect belongs to, in place and for free (from wherever it
## is, e.g. the discard pile): its on-play effects resolve and it counts as a
## play. The card does not move. Used by the Boomerang enhancement.


func apply(ctx: EffectContext) -> void:
	if ctx.card == null or not ctx.card.is_playable_kind():
		return
	await ctx.encounter.play_in_place(ctx.owner, ctx.card)


func describe() -> String:
	return "Play this card"


func ai_score() -> float:
	return 1.0

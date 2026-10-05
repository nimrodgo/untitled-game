class_name RetainCardsEffect
extends Effect
## Choose cards in your hand to keep at the end of this turn.
## `optional`: "You may retain..." (pick up to `amount`).

@export var amount: int = 1
@export var optional: bool = false


func apply(ctx: EffectContext) -> void:
	var picks: Array = await ctx.encounter.choose_cards(ctx.owner, GameRules.PILE_HAND, amount, "Retain", ctx,
		optional, func(c: CardInstance): return not c.is_retained(), ctx.card)
	for c in picks:
		c.retain = true
		ctx.encounter.log_line("  %s retain %s." % [ctx.owner.display_name, c.get_name()])


func describe() -> String:
	var n := Icons.n(amount, "📌")
	return ("You may %s" if optional else "%s") % n


func ai_score() -> float:
	return 0.5 * amount

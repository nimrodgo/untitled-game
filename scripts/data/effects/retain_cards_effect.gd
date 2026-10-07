class_name RetainCardsEffect
extends Effect
## Choose cards in your hand to keep at the end of this turn.
## `optional`: "You may retain..." (pick up to `amount`).
## `all_hand`: retain every other card in your hand, no choice.

@export var amount: int = 1
@export var optional: bool = false
@export var all_hand: bool = false


func apply(ctx: EffectContext) -> void:
	if all_hand:
		for c in ctx.owner.hand:
			if c != ctx.card and not c.is_retained():
				c.retain = true
		ctx.encounter.log_line("  %s retain their hand." % ctx.owner.display_name)
		return
	var picks: Array = await ctx.encounter.choose_cards(ctx.owner, GameRules.PILE_HAND, amount, "Retain", ctx,
		optional, func(c: CardInstance): return not c.is_retained(), ctx.card)
	for c in picks:
		c.retain = true
		ctx.encounter.log_line("  %s retain %s." % [ctx.owner.display_name, c.get_name()])


func describe() -> String:
	if all_hand:
		return "📌 your hand"
	var n := Icons.n(amount, "📌")
	return ("You may %s" if optional else "%s") % n


func ai_score() -> float:
	return 1.5 if all_hand else 0.5 * amount

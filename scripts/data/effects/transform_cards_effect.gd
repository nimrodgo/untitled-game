class_name TransformCardsEffect
extends Effect
## Choose any number of cards in your hand; each becomes `into` (its
## upgrades are lost).

@export var into: CardData


func apply(ctx: EffectContext) -> void:
	if into == null:
		return
	var p := ctx.owner
	var picks: Array = await ctx.encounter.choose_cards(p, GameRules.PILE_HAND, p.hand.size(), "Transform", ctx,
		true, func(c: CardInstance): return c.data != into, ctx.card)
	for c in picks:
		ctx.encounter.log_line("  %s transform %s into %s." % [p.display_name, c.get_name(), into.display_name])
		c.data = into
		c.enhancements.clear()


func describe() -> String:
	return "Transform any cards in your hand to %s" % (into.display_name if into else "?")


func ai_score() -> float:
	return 0.0

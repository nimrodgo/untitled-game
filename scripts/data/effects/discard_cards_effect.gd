class_name DiscardCardsEffect
extends Effect
## The owner discards cards from their hand: chosen ones, or the whole hand.
## `as_cost`: "Discard a card to ..." (unplayable without enough other cards).
## `draw_that_many`: "Discard your hand. Draw that many cards".

@export var amount: int = 1
@export var all_hand: bool = false
@export var as_cost: bool = false
@export var draw_that_many: bool = false


func can_pay(ctx: EffectContext) -> bool:
	if not as_cost or all_hand:
		return true
	var others := ctx.owner.hand.size() - (1 if ctx.owner.hand.has(ctx.card) else 0)
	return others >= amount


func apply(ctx: EffectContext) -> void:
	var enc := ctx.encounter
	var p := ctx.owner
	var picks: Array
	if all_hand:
		picks = p.hand.duplicate()
	else:
		picks = await enc.choose_cards(p, GameRules.PILE_HAND, amount, "Discard", ctx, false, Callable(), ctx.card)
	await enc.discard_cards(p, picks)
	if draw_that_many and not picks.is_empty():
		await enc.draw_cards(p, picks.size())


func is_cost() -> bool:
	return as_cost


func describe() -> String:
	if all_hand:
		return "Discard your hand ⤵" + (". Draw that many 🂠" if draw_that_many else "")
	return "Discard %d ⤵" % amount


func ai_score() -> float:
	return 0.5 if draw_that_many else -0.8 * amount

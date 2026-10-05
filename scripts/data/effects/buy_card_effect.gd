class_name BuyCardEffect
extends Effect
## Buy a card as part of this effect (it isn't a separate action).
## source: a market card, or a card you removed / destroyed this encounter.
## `free`: don't pay. `zone`: where it goes (-1 = the normal destination).
## `play_then_destroy`: play it right away, then destroy it.
## You choose among the cards you can afford.

enum Source { MARKET, REMOVED, DESTROYED }

@export var source: Source = Source.MARKET
@export var free: bool = false
@export var zone: int = -1
@export var play_then_destroy: bool = false


func _cost(ctx: EffectContext, cost: int) -> int:
	return 0 if free else ctx.encounter.card_price(ctx.owner, cost)


func apply(ctx: EffectContext) -> void:
	var enc := ctx.encounter
	var p := ctx.owner
	var req := ChoiceRequest.new()
	req.verb = "Buy"
	req.source_name = ctx.source_name
	req.source_card = ctx.card
	req.min_count = 1
	req.max_count = 1
	if source == Source.MARKET:
		req.kind = ChoiceRequest.Kind.SHOP_CARD
		for i in enc.shop.cards.size():
			var cd: CardData = enc.shop.cards[i]
			if cd and p.coins >= _cost(ctx, cd.cost):
				req.candidates.append(i)
	else:
		req.kind = ChoiceRequest.Kind.CARD_DATA
		for c in (p.removed if source == Source.REMOVED else p.destroyed):
			if c != ctx.card and p.coins >= _cost(ctx, c.get_cost()):
				req.candidates.append(c)
	var picks: Array = await enc.request_choice(req)
	if picks.is_empty():
		return
	var card: CardInstance
	if source == Source.MARKET:
		card = CardInstance.new(enc.shop.take_card(picks[0]))
	else:
		card = picks[0]
		p.removed.erase(card)
		p.destroyed.erase(card)
	await enc.buy_instance(p, card, _cost(ctx, card.get_cost()), zone, not play_then_destroy)
	if play_then_destroy:
		await enc.play_extra(p, card)
		await enc.trash_card(p, card, true)


func describe() -> String:
	var what := "a card"
	match source:
		Source.REMOVED: what = "a card you removed this encounter"
		Source.DESTROYED: what = "a card you destroyed this encounter"
	var t := "Buy %s%s" % [what, " for free" if free else ""]
	if play_then_destroy:
		t += " and play it immediately. Then destroy it"
	elif zone == GameRules.Zone.DRAW_TOP:
		t += " and place it on top of the draw pile"
	elif zone == GameRules.Zone.HAND:
		t += " into your hand"
	return t


func ai_score() -> float:
	return 2.0 if free else 0.8

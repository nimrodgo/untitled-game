class_name DestroyShopCardEffect
extends Effect
## Choose a market card and destroy it; `restock` puts a new random card in
## that slot.

@export var restock: bool = true


func apply(ctx: EffectContext) -> void:
	var enc := ctx.encounter
	var req := ChoiceRequest.new()
	req.kind = ChoiceRequest.Kind.SHOP_CARD
	req.verb = "Destroy"
	req.source_name = ctx.source_name
	req.source_card = ctx.card
	for i in enc.shop.cards.size():
		if enc.shop.cards[i] != null:
			req.candidates.append(i)
	var picks: Array = await enc.request_choice(req)
	for slot in picks:
		var cd: CardData = enc.shop.cards[slot]
		enc.shop.cards[slot] = null
		enc.log_line("  %s destroy %s in the market." % [ctx.owner.display_name, cd.display_name])
		if restock:
			enc.shop.restock_card_slot(slot)


func describe() -> String:
	return "Destroy a card in the shop" + (" and restock it" if restock else "")


func ai_score() -> float:
	return 0.2

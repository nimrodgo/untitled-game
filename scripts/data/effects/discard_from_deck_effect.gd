class_name DiscardFromDeckEffect
extends Effect
## Look at the top `look` cards of your deck; you may discard any of them
## (the rest stay on top in the same order).

@export var look: int = 1


func apply(ctx: EffectContext) -> void:
	var enc := ctx.encounter
	var p := ctx.owner
	var top: Array = []
	for i in mini(look, p.draw_pile.size()):
		top.append(p.draw_pile[p.draw_pile.size() - 1 - i])
	if top.is_empty():
		return
	var req := ChoiceRequest.new()
	req.kind = ChoiceRequest.Kind.CARDS
	req.verb = "Discard"
	req.candidates = top
	req.ordered = true
	for i in top.size():
		req.groups.append("Top" if i == 0 else "#%d" % (i + 1))
	req.min_count = 0
	req.max_count = top.size()
	req.source_name = ctx.source_name
	req.source_card = ctx.card
	var picks: Array = await enc.request_choice(req)
	await enc.discard_cards(p, picks)


func describe() -> String:
	if look == 1:
		return "You may discard ⤵ the top card of your deck"
	return "Look at the top %d cards of your deck. Discard ⤵ any of them" % look


func ai_score() -> float:
	return 0.3 * look

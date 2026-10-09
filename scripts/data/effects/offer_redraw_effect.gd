class_name OfferRedrawEffect
extends Effect
## For CARD_DRAWN charms: you may discard the card just drawn to draw another.
## Declining (or the start-of-turn draw) doesn't use up the charm.


func apply(ctx: EffectContext) -> void:
	var enc := ctx.encounter
	var c := ctx.card
	if ctx.opening_draw or c == null or not ctx.owner.hand.has(c) or ctx.owner.draw_locked:
		ctx.declined = true
		return
	var req := ChoiceRequest.new()
	req.kind = ChoiceRequest.Kind.OPTIONS
	req.verb = "Redraw?"
	req.source_name = ctx.source_name
	req.source_card = c
	req.candidates = ["Discard %s and draw another" % c.get_name(), "Keep it"]
	var picks: Array = await enc.request_choice(req)
	if picks[0] != 0:
		ctx.declined = true
		return
	await enc.discard_cards(ctx.owner, [c])
	await enc.draw_cards(ctx.owner, 1)


func describe() -> String:
	return "You may discard it to draw another"


func ai_score() -> float:
	return 0.5

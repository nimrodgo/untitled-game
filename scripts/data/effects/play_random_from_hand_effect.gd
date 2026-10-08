class_name PlayRandomFromHandEffect
extends Effect
## Play a random card from your hand: only cards you could play right now
## (curses and cards whose cost can't be paid are skipped). Counts as playing
## a card; nothing happens if no card qualifies. (Mimic's on-buy.)

func apply(ctx: EffectContext) -> void:
	var enc := ctx.encounter
	var p := ctx.owner
	var cands: Array = p.hand.filter(func(c: CardInstance): return c != ctx.card and enc.can_pay_card(p, c))
	if cands.is_empty():
		return
	var c: CardInstance = cands[enc.rng.randi_range(0, cands.size() - 1)]
	await enc.play_extra(p, c)


func describe() -> String:
	return "Play a random card from your hand"


func ai_score() -> float:
	return 1.0

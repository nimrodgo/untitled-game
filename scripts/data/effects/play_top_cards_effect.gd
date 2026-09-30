class_name PlayTopCardsEffect
extends Effect
## Play the top N cards of your deck (they count as played cards).
## Unplayable cards revealed this way go to the discard pile instead.

@export var amount: int = 2


func apply(ctx: EffectContext) -> void:
	var enc := ctx.encounter
	var p := ctx.owner
	for i in amount:
		if enc.is_over:
			return
		if p.draw_pile.is_empty():
			if p.discard.is_empty():
				return
			p.draw_pile = p.discard.duplicate()
			p.discard.clear()
			enc._shuffle(p.draw_pile)
		var c: CardInstance = p.draw_pile.back()
		if not c.data.playable:
			enc.move_card(p, c, GameRules.Zone.DISCARD)
			enc.log_line("  %s can't play %s; it goes to the discard pile." % [p.display_name, c.get_name()])
			continue
		await enc.play_extra(p, c)


func describe() -> String:
	return "Play the top %d cards of your deck" % amount if amount != 1 else "Play the top card of your deck"


func ai_score() -> float:
	return 1.2 * amount

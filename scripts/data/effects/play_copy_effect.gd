class_name PlayCopyEffect
extends Effect
## Resolve another card's on-play effects (counts as playing a card).
## DESTROYED: choose a card destroyed this encounter.
## LAST_PLAYED: the last card you played this turn (before this one).

enum Source { DESTROYED, LAST_PLAYED }

@export var source: Source = Source.LAST_PLAYED


func apply(ctx: EffectContext) -> void:
	var enc := ctx.encounter
	var p := ctx.owner
	var card: CardInstance
	if source == Source.LAST_PLAYED:
		for i in range(p.played_log.size() - 1, -1, -1):
			if p.played_log[i] != ctx.card:
				card = p.played_log[i]
				break
	else:
		var req := ChoiceRequest.new()
		req.kind = ChoiceRequest.Kind.CARD_DATA
		req.verb = "Play"
		req.source_name = ctx.source_name
		req.source_card = ctx.card
		for c in p.destroyed:
			if c != ctx.card and c.data.playable:
				req.candidates.append(c)
		var picks: Array = await enc.request_choice(req)
		if not picks.is_empty():
			card = picks[0]
	if card:
		await enc.play_copy(p, card)


func describe() -> String:
	if source == Source.DESTROYED:
		return "Play the effect of a card that was destroyed this encounter"
	return "Play the effect of the last card you played this turn"


func ai_score() -> float:
	return 1.0

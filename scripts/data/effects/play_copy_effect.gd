class_name PlayCopyEffect
extends Effect
## Resolve another card's on-play effects (counts as playing a card).
## DESTROYED: choose a card destroyed this encounter.
## LAST_PLAYED: the last card you played this turn (before this one).
## Cards that themselves play copies (Mimic, Necromancy) are skipped, or two of
## them would copy each other forever.

enum Source { DESTROYED, LAST_PLAYED }

@export var source: Source = Source.LAST_PLAYED


func apply(ctx: EffectContext) -> void:
	var enc := ctx.encounter
	var p := ctx.owner
	var card: CardInstance
	if source == Source.LAST_PLAYED:
		for i in range(p.played_log.size() - 1, -1, -1):
			if p.played_log[i] != ctx.card and not plays_copies(p.played_log[i]):
				card = p.played_log[i]
				break
	else:
		var req := ChoiceRequest.new()
		req.kind = ChoiceRequest.Kind.CARD_DATA
		req.verb = "Play"
		req.source_name = ctx.source_name
		req.source_card = ctx.card
		for c in p.destroyed:
			if c != ctx.card and c.data.playable and not plays_copies(c):
				req.candidates.append(c)
		var picks: Array = await enc.request_choice(req)
		if not picks.is_empty():
			card = picks[0]
	if card:
		await enc.play_copy(p, card)


## True if the card's on-play includes a PlayCopyEffect.
static func plays_copies(c: CardInstance) -> bool:
	return c.get_on_play().any(func(e: Effect): return e is PlayCopyEffect)


func describe() -> String:
	if source == Source.DESTROYED:
		return "Play the effect of a card that was destroyed this encounter"
	return "Play the effect of the last card you played this turn"


func ai_score() -> float:
	return 1.0

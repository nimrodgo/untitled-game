class_name ReplayEffect
extends Effect
## NEXT_CARD: the next card you play this turn is played an additional time.
## THIS_CARD: play ctx.card's effect again now (for items on CARD_PLAYED).

enum Mode { NEXT_CARD, THIS_CARD }

@export var mode: Mode = Mode.NEXT_CARD
@export var times: int = 1


func apply(ctx: EffectContext) -> void:
	if mode == Mode.NEXT_CARD:
		ctx.owner.replay_next += times
		return
	if ctx.card == null:
		return
	for i in times:
		await ctx.encounter.play_copy(ctx.owner, ctx.card)


func describe() -> String:
	if mode == Mode.NEXT_CARD:
		return "The next card you play this turn is played an additional time"
	return "Play it an extra time"


func ai_score() -> float:
	return 1.5 * times

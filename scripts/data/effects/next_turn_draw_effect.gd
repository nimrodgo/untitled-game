class_name NextTurnDrawEffect
extends Effect
## Draw extra cards at the start of your next turn.

@export var amount: int = 1


func apply(ctx: EffectContext) -> void:
	ctx.owner.bonus_draw_next_turn += amount


func describe() -> String:
	return "%s at the start of your next turn" % Icons.n(amount, "🂠")


func ai_score() -> float:
	return 0.8 * amount

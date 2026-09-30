class_name DrawLockEffect
extends Effect
## "You can't draw additional cards this turn."


func apply(ctx: EffectContext) -> void:
	ctx.owner.draw_locked = true


func describe() -> String:
	return "You can't draw additional cards this turn"


func ai_score() -> float:
	return -0.5

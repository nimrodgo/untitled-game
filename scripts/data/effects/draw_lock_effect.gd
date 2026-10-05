class_name DrawLockEffect
extends Effect
## "You can't draw additional cards this turn." On an enemy intent
## (target = OPPONENT) it locks the player's draws.


func apply(ctx: EffectContext) -> void:
	ctx.resolve(target).draw_locked = true


func describe() -> String:
	return "You can't draw additional cards this turn"


func ai_score() -> float:
	return -0.5

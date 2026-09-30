class_name PassEffect
extends Effect
## Your turn ends right after this action (the enemy doesn't answer it).


func apply(ctx: EffectContext) -> void:
	ctx.pass_after = true


func is_cost() -> bool:
	return true


func describe() -> String:
	return "Pass"


func ai_score() -> float:
	return -1.5

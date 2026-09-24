class_name ExtraActionEffect
extends Effect
## After this resolves, the owner's turn does not end (take another action).


func apply(ctx: EffectContext) -> void:
	ctx.grant_extra_action = true


func describe() -> String:
	return "Take another action"


func ai_score() -> float:
	return 1.5

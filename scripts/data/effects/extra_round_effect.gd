class_name ExtraRoundEffect
extends Effect
## The encounter gets one more round (a normal round: the market restocks
## and the enemy's actions refill).

@export var amount: int = 1


func apply(ctx: EffectContext) -> void:
	ctx.encounter.extra_rounds += amount
	ctx.encounter.log_line("  %s take an extra turn!" % ctx.owner.display_name)


func describe() -> String:
	return "Take an extra turn"


func ai_score() -> float:
	return 5.0

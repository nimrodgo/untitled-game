class_name ReduceTargetEffect
extends Effect
## Lower the coins you need to win this encounter (never below 0).

@export var amount: int = 3


func apply(ctx: EffectContext) -> void:
	var enc := ctx.encounter
	enc.target_reduction += amount
	enc.log_line("  The target drops to %d coins." % enc.coin_target())


func describe() -> String:
	return "Reduce the encounter target by %d" % amount


func ai_score() -> float:
	return float(amount)

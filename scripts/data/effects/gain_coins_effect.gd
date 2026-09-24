class_name GainCoinsEffect
extends Effect

@export var amount: int = 1


func apply(ctx: EffectContext) -> void:
	ctx.encounter.change_coins(ctx.resolve(target), amount, ctx.source_name)


func describe() -> String:
	return "%sGain %d 🪙" % [_who(), amount]


func ai_score() -> float:
	return float(amount) if target == GameRules.Target.SELF else -float(amount)

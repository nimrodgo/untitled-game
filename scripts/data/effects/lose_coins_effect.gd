class_name LoseCoinsEffect
extends Effect

@export var amount: int = 1


func apply(ctx: EffectContext) -> void:
	ctx.encounter.change_coins(ctx.resolve(target), -amount, ctx.source_name)


func describe() -> String:
	if enemy_voice and target == GameRules.Target.OPPONENT:
		return "You -%d🪙" % amount
	return "%s-%d🪙" % [_who(), amount]


func ai_score() -> float:
	return amount * 0.9 if target == GameRules.Target.OPPONENT else -float(amount)

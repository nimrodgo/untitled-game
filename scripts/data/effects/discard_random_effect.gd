class_name DiscardRandomEffect
extends Effect

@export var amount: int = 1


func apply(ctx: EffectContext) -> void:
	ctx.encounter.discard_random(ctx.resolve(target), amount)


func describe() -> String:
	return "%s%s at random" % [_who(), Icons.n(amount, "⤵")]


func ai_score() -> float:
	return amount * 0.8 if target == GameRules.Target.OPPONENT else -float(amount)

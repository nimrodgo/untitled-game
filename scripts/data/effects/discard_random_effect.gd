class_name DiscardRandomEffect
extends Effect

@export var amount: int = 1


func _init() -> void:
	target = GameRules.Target.OPPONENT


func apply(ctx: EffectContext) -> void:
	ctx.encounter.discard_random(ctx.resolve(target), amount)


func describe() -> String:
	return "%sDiscard %d at random" % [_who(), amount]


func ai_score() -> float:
	return amount * 0.8 if target == GameRules.Target.OPPONENT else -float(amount)

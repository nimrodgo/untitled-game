class_name DrawCardsEffect
extends Effect

@export var amount: int = 1


func apply(ctx: EffectContext) -> void:
	ctx.encounter.draw_cards(ctx.resolve(target), amount)


func describe() -> String:
	return "%sDraw %d 🂠" % [_who(), amount]


func ai_score() -> float:
	return amount * 1.0 if target == GameRules.Target.SELF else -amount * 0.8

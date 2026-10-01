class_name PayCoinsEffect
extends Effect
## A cost: pay coins. The card / trinket can't be used if you can't pay.
## (LoseCoinsEffect is the "lose what you have" version.)

@export var amount: int = 1


func can_pay(ctx: EffectContext) -> bool:
	return ctx.owner.coins >= amount


func apply(ctx: EffectContext) -> void:
	ctx.encounter.change_coins(ctx.owner, -amount, ctx.source_name)


func is_cost() -> bool:
	return true


func describe() -> String:
	return "-%d🪙" % amount


func ai_score() -> float:
	return -float(amount)

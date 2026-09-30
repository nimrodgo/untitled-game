class_name NextBuyToHandEffect
extends Effect
## "The next card you buy is drawn immediately."

@export var amount: int = 1


func apply(ctx: EffectContext) -> void:
	ctx.owner.next_buy_to_hand += amount


func describe() -> String:
	return "The next card you buy is drawn immediately"


func ai_score() -> float:
	return 0.6

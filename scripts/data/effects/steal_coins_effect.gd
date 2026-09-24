class_name StealCoinsEffect
extends Effect
## Moves coins from the opponent to the owner (target is ignored).

@export var amount: int = 1


func apply(ctx: EffectContext) -> void:
	var taken: int = mini(amount, ctx.opponent.coins)
	if taken > 0:
		ctx.encounter.change_coins(ctx.opponent, -taken, ctx.source_name)
		ctx.encounter.change_coins(ctx.owner, taken, ctx.source_name)


func describe() -> String:
	return "Steal %d 🪙" % amount


func ai_score() -> float:
	return amount * 1.8

class_name GainCoinsScalingEffect
extends Effect
## Gain `amount` coins plus this card's bonus, then raise the bonus of every
## card with the same id by `increase` for the rest of the encounter.
## ("P1: Gain 2 coins and increase gain from all P1s by 2 this encounter")

@export var amount: int = 2
@export var increase: int = 2


func apply(ctx: EffectContext) -> void:
	var key: StringName = ctx.card.data.id if ctx.card else &""
	var p := ctx.owner
	var bonus: int = p.card_bonus.get(key, 0)
	ctx.encounter.change_coins(p, amount + bonus, ctx.source_name)
	p.card_bonus[key] = bonus + increase


func describe() -> String:
	return "Gain %d 🪙 and increase gain from all copies of this card by %d this encounter" % [amount, increase]


func ai_score() -> float:
	return amount + increase * 0.5

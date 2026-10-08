class_name BoostCardBonusEffect
extends Effect
## Raise the scaling bonus of every card with this card's id by `increase` for
## the rest of the encounter, without gaining anything now (Snowball's on-buy:
## "increase 🪙 gain from all Snowballs by 1"). See GainCoinsScalingEffect.

@export var increase: int = 1


func apply(ctx: EffectContext) -> void:
	if ctx.card == null:
		return
	var key: StringName = ctx.card.data.id
	ctx.owner.card_bonus[key] = int(ctx.owner.card_bonus.get(key, 0)) + increase
	ctx.encounter.log_line("  All %s gain %d more this encounter." % [ctx.card.get_name(), increase])


func describe() -> String:
	return "Increase 🪙 gain from all copies of this card by %d this encounter" % increase


func ai_score() -> float:
	return 0.5 * increase

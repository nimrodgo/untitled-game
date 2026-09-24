class_name SnatchShopCardEffect
extends Effect
## Removes a card from the market (it refills if the encounter refills).
## Meant for enemy intents, but works on player cards too.

enum Mode { CHEAPEST, PRICIEST, RANDOM, LEFTMOST }

@export var mode: Mode = Mode.PRICIEST
@export var amount: int = 1


func apply(ctx: EffectContext) -> void:
	for i in amount:
		var cd := ctx.encounter.shop.snatch_card(mode, ctx.encounter.rng)
		if cd:
			ctx.encounter.log_line("  %s snatch %s from the market." % [ctx.owner.display_name, cd.display_name])


func describe() -> String:
	var which := ""
	match mode:
		Mode.CHEAPEST: which = "the cheapest"
		Mode.PRICIEST: which = "the priciest"
		Mode.RANDOM: which = "a random"
		Mode.LEFTMOST: which = "the leftmost"
	return "Snatch %s market card%s" % [which, "" if amount == 1 else " ×%d" % amount]


func ai_score() -> float:
	return 0.5 * amount

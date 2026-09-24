class_name GainCoinsPerStatEffect
extends Effect
## Gain `per` coins for every point of a tracked stat of the owner, e.g.
## stat = "cards_drawn_this_turn". See PlayerState for available stats.

@export var stat: StringName = &"cards_drawn_this_turn"
@export var per: int = 1


func apply(ctx: EffectContext) -> void:
	var who := ctx.resolve(target)
	var n: int = int(who.get(stat)) if stat in who else 0
	if n * per != 0:
		ctx.encounter.change_coins(who, n * per, ctx.source_name)


func describe() -> String:
	return "%sGain %d 🪙 for every %s" % [_who(), per, String(stat).replace("_", " ")]


func ai_score() -> float:
	return 1.0 * per

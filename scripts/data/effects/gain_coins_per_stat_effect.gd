class_name GainCoinsPerStatEffect
extends Effect
## Gain `per` coins for every point of a tracked stat of the owner, e.g.
## stat = "cards_drawn_this_turn". See PlayerState for available stats.
## A pile works too ("discard", "hand", "draw_pile"): one point per card in it.

@export var stat: StringName = &"cards_drawn_this_turn"
@export var per: int = 1


func apply(ctx: EffectContext) -> void:
	var who := ctx.resolve(target)
	var n := _points(who)
	if n * per != 0:
		ctx.encounter.change_coins(who, n * per, ctx.source_name)


func _points(who: PlayerState) -> int:
	if not stat in who:
		return 0
	var v: Variant = who.get(stat)
	return v.size() if v is Array else int(v)


func preview_coins(_enc: Encounter, owner: PlayerState, _cd: CardData, _card: CardInstance) -> int:
	return _points(owner) * per if target == GameRules.Target.SELF else 0


func describe() -> String:
	return "%s+%d🪙 for every %s" % [_who(), per, String(stat).replace("_", " ")]


func ai_score() -> float:
	return 1.0 * per

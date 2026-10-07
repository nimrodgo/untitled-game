class_name AddRandomCurseEffect
extends Effect
## Adds `amount` random curses from `curses` (picked with the encounter's rng).

@export var curses: Array[CardData] = []
@export var amount: int = 1
@export var zone: GameRules.Zone = GameRules.Zone.DRAW_BOTTOM


func apply(ctx: EffectContext) -> void:
	if curses.is_empty():
		return
	var who := ctx.resolve(target)
	for i in amount:
		ctx.encounter.add_card(who, curses[ctx.encounter.rng.randi_range(0, curses.size() - 1)], zone)


func describe() -> String:
	var where := "deck (bottom)"
	match zone:
		GameRules.Zone.HAND: where = "hand"
		GameRules.Zone.DISCARD: where = "discard"
		GameRules.Zone.DRAW_TOP: where = "deck (top)"
	return "%sAdd %s to your %s" % [_who(), "a random curse" if amount == 1 else "%d random curses" % amount, where]


func ai_score() -> float:
	return -1.0 * amount

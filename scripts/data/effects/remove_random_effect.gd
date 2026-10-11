class_name RemoveRandomEffect
extends Effect
## Remove (🗑, for this encounter) random cards from someone's hand, or destroy
## them (`destroy`). Made for enemies (they never get choices): the Gulper Eel.

@export var amount: int = 1
@export var destroy: bool = false


func apply(ctx: EffectContext) -> void:
	var enc := ctx.encounter
	var who := ctx.resolve(target)
	var pool: Array = who.hand.duplicate()
	for i in mini(amount, pool.size()):
		var c: CardInstance = pool.pop_at(enc.rng.randi_range(0, pool.size() - 1))
		await enc.trash_card(who, c, destroy)


func describe() -> String:
	var icon := "🔥" if destroy else "🗑"
	var what := "a card" if amount == 1 else "%d cards" % amount
	return "%s%s %s in your hand at random" % [_who(), icon, what]


func ai_score() -> float:
	return amount * 1.2 if target == GameRules.Target.OPPONENT else -amount * 1.5

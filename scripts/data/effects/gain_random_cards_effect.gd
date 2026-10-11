class_name GainRandomCardsEffect
extends Effect
## Gain `amount` random cards from the shop's card pool (the encounter's sets
## plus extras), temporary (⏳) by default.
## zone HAND with `as_draw`: they are drawn (count as draws, blocked by draw
## locks, fire CARD_DRAWN).

@export var amount: int = 1
@export var zone: GameRules.Zone = GameRules.Zone.DRAW_BOTTOM
@export var temporary: bool = true
@export var as_draw: bool = false


func apply(ctx: EffectContext) -> void:
	var enc := ctx.encounter
	var who := ctx.resolve(target)
	for i in amount:
		var cd: CardData = enc.shop.random_pool_card()
		if cd == null:
			return
		if as_draw and zone == GameRules.Zone.HAND:
			var c := enc.make_card(cd, temporary)
			if not await enc.draw_specific(who, c):
				return
			await enc.card_created(who, c, ctx.owner)
		else:
			await enc.add_card(who, cd, zone, temporary, ctx.owner)


func describe() -> String:
	var t := "⏳ " if temporary else ""
	var what := "%d random %scard%s from the shop's sets" % [amount, t, "" if amount == 1 else "s"]
	if as_draw and zone == GameRules.Zone.HAND:
		return "%s%s %s" % [_who(), Icons.n(amount, "🂠"), what]
	var where := "the bottom of your deck"
	match zone:
		GameRules.Zone.HAND: where = "your hand"
		GameRules.Zone.DISCARD: where = "your discard pile"
		GameRules.Zone.DRAW_TOP: where = "the top of your deck"
	return "%sGain %s to %s" % [_who(), what, where]


func ai_score() -> float:
	return amount * (1.0 if zone == GameRules.Zone.HAND else 0.6)

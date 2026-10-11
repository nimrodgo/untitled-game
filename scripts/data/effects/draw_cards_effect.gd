class_name DrawCardsEffect
extends Effect
## Draw cards. source: the top of the deck (default), the bottom, or cards
## you choose from the discard pile.
## `retain_drawn`: 📌 the cards this effect drew (only those; cards drawn by
## charm triggers meanwhile are not retained, nor ones that left the hand).
## `temp_copy_drawn`: also put a temporary (⏳) copy of each card this effect
## drew into your hand (plain card + Temporary; not a draw).

enum Source { TOP, BOTTOM, DISCARD_CHOOSE }

@export var amount: int = 1
@export var source: Source = Source.TOP
@export var retain_drawn: bool = false
@export var temp_copy_drawn: bool = false


func apply(ctx: EffectContext) -> void:
	var who := ctx.resolve(target)
	var drawn: Array = []
	match source:
		Source.DISCARD_CHOOSE:
			var picks: Array = await ctx.encounter.choose_cards(who, GameRules.PILE_DISCARD, amount, "Draw", ctx)
			for c in picks:
				if await ctx.encounter.draw_specific(who, c):
					drawn.append(c)
		Source.BOTTOM:
			await ctx.encounter.draw_cards(who, amount, true, false, drawn)
		_:
			await ctx.encounter.draw_cards(who, amount, false, false, drawn)
	if retain_drawn:
		for c in drawn:
			if who.hand.has(c):
				c.retain = true
		if not drawn.is_empty():
			ctx.encounter.log_line("  %s retain the drawn cards." % who.display_name)
	if temp_copy_drawn:
		for c in drawn:
			await ctx.encounter.add_card(who, c.data, GameRules.Zone.HAND, true, ctx.owner)


func describe() -> String:
	var n := Icons.n(amount, "🂠")
	var s := "%s%s" % [_who(), n]
	match source:
		Source.BOTTOM: s += " from the bottom of your deck"
		Source.DISCARD_CHOOSE: s += " from the discard pile"
	if retain_drawn:
		s += (" and 📌 it" if amount == 1 else " and 📌 them")
	if temp_copy_drawn:
		s += (" and get a ⏳ copy of it" if amount == 1 else " and get a ⏳ copy of each")
	return s


func ai_score() -> float:
	if target != GameRules.Target.SELF:
		return -amount * 0.8
	return amount * (1.5 if retain_drawn else 1.0) * (1.8 if temp_copy_drawn else 1.0)

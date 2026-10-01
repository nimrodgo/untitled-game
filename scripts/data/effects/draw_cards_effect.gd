class_name DrawCardsEffect
extends Effect
## Draw cards. source: the top of the deck (default), the bottom, or cards
## you choose from the discard pile.

enum Source { TOP, BOTTOM, DISCARD_CHOOSE }

@export var amount: int = 1
@export var source: Source = Source.TOP


func apply(ctx: EffectContext) -> void:
	var who := ctx.resolve(target)
	match source:
		Source.DISCARD_CHOOSE:
			var picks: Array = await ctx.encounter.choose_cards(who, GameRules.PILE_DISCARD, amount, "Draw", ctx)
			for c in picks:
				await ctx.encounter.draw_specific(who, c)
		Source.BOTTOM:
			await ctx.encounter.draw_cards(who, amount, true)
		_:
			await ctx.encounter.draw_cards(who, amount)


func describe() -> String:
	var n := Icons.n(amount, "🂠")
	match source:
		Source.BOTTOM: return "%s%s from the bottom of your deck" % [_who(), n]
		Source.DISCARD_CHOOSE: return "%s%s from the discard pile" % [_who(), n]
	return "%s%s" % [_who(), n]


func ai_score() -> float:
	return amount * 1.0 if target == GameRules.Target.SELF else -amount * 0.8

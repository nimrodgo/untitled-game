class_name ConditionalEffect
extends Effect
## Resolves `effects` only if the condition holds when it resolves.

enum Condition {
	DISCARD_EMPTY,        ## your discard pile is empty
	DECK_EMPTY,           ## your draw pile ("deck") is empty
	NO_OTHER_CARD_PLAYED, ## you haven't played any other card this turn
}

@export var condition: Condition = Condition.DISCARD_EMPTY
@export var effects: Array[Effect] = []


func holds(ctx: EffectContext) -> bool:
	var p := ctx.owner
	match condition:
		Condition.DISCARD_EMPTY: return p.discard.is_empty()
		Condition.DECK_EMPTY: return p.draw_pile.is_empty()
		Condition.NO_OTHER_CARD_PLAYED:
			for c in p.played_log:
				if c != ctx.card:
					return false
			return true
	return false


func apply(ctx: EffectContext) -> void:
	if holds(ctx):
		await ctx.encounter.run_effects(effects, ctx)


func describe() -> String:
	var cond := ""
	match condition:
		Condition.DISCARD_EMPTY: cond = "If your discard pile is empty"
		Condition.DECK_EMPTY: cond = "If your deck is empty"
		Condition.NO_OTHER_CARD_PLAYED: cond = "If you didn't play any card this turn"
	var inner := Effect.describe_list(effects)
	return "%s, %s" % [cond, inner.left(1).to_lower() + inner.substr(1)]


func ai_score() -> float:
	return Effect.score_list(effects) * 0.4

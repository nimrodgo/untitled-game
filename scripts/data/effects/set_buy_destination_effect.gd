class_name SetBuyDestinationEffect
extends Effect
## Only meaningful on a BEFORE_CARD_BUY item trigger (or a card's on-buy):
## changes where the bought card goes.

@export var destination: GameRules.Zone = GameRules.Zone.HAND


func apply(ctx: EffectContext) -> void:
	ctx.buy_destination = destination


func describe() -> String:
	match destination:
		GameRules.Zone.HAND: return "Bought card goes to your hand"
		GameRules.Zone.DRAW_TOP: return "Bought card goes on top of your deck"
		GameRules.Zone.DISCARD: return "Bought card goes to your discard"
	return "Bought card is shuffled into your deck"


func ai_score() -> float:
	return 0.5

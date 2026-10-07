class_name SetBuyDestinationEffect
extends Effect
## Only meaningful on a BEFORE_CARD_BUY item trigger (or a card's on-buy):
## changes where the bought card goes.
## `optional`: the owner is asked each time ("you may place it on top...").

@export var destination: GameRules.Zone = GameRules.Zone.HAND
@export var optional: bool = false


func apply(ctx: EffectContext) -> void:
	if optional:
		var req := ChoiceRequest.new()
		req.kind = ChoiceRequest.Kind.OPTIONS
		req.verb = "Choose"
		req.source_name = ctx.source_name
		req.source_card = ctx.card
		req.candidates = [_place_label(), "Don't"]
		var picks: Array = await ctx.encounter.request_choice(req)
		if picks[0] != 0:
			ctx.declined = true
			return
	ctx.buy_destination = destination


func _place_label() -> String:
	match destination:
		GameRules.Zone.HAND: return "Put it in your hand"
		GameRules.Zone.DRAW_TOP: return "Put it on top of your deck"
		GameRules.Zone.DISCARD: return "Put it in your discard pile"
	return "Put it at the bottom of your deck"


func describe() -> String:
	if optional:
		match destination:
			GameRules.Zone.HAND: return "You may put the bought card in your hand"
			GameRules.Zone.DRAW_TOP: return "You may put the bought card on top of your deck"
			GameRules.Zone.DISCARD: return "You may put the bought card in your discard pile"
		return "You may put the bought card at the bottom of your deck"
	match destination:
		GameRules.Zone.HAND: return "Bought card goes to your hand"
		GameRules.Zone.DRAW_TOP: return "Bought card goes on top of your deck"
		GameRules.Zone.DISCARD: return "Bought card goes to your discard"
	return "Bought card goes to the bottom of your deck"


func ai_score() -> float:
	return 0.5

class_name TrashCardsEffect
extends Effect
## Remove cards for this encounter (destroy = false) or destroy them
## permanently (destroy = true).
## what:
## - SELF: this card (the one being played / bought, or ctx.card for items).
## - CHOOSE: the owner picks exactly `amount` from `piles` (fewer if there
##   aren't enough). Curses only when `curses_only`.
## - ALL_OTHER_HAND: every other card in the owner's hand.
## - DRAW_PILE: the owner's whole draw pile ("your deck").
## Bonuses: `coins_per_card` for each card, and/or coins equal to each card's cost.

enum What { SELF, CHOOSE, ALL_OTHER_HAND, DRAW_PILE }

@export var destroy: bool = true
@export var what: What = What.CHOOSE
@export var amount: int = 1
## GameRules.PILE_* flags. Default: deck, hand or discard.
@export_flags("Hand:1", "Deck:2", "Discard:4") var piles: int = GameRules.PILES_ALL
@export var curses_only: bool = false
@export var coins_per_card: int = 0
@export var gain_cost_as_coins: bool = false
## Text only: "🔥 this ➡ ..." when this is the price of the rest.
@export var as_cost: bool = false


func apply(ctx: EffectContext) -> void:
	var enc := ctx.encounter
	var p := ctx.owner
	var cards: Array = []
	match what:
		What.SELF:
			if ctx.card:
				cards = [ctx.card]
		What.ALL_OTHER_HAND:
			for c in p.hand:
				if c != ctx.card:
					cards.append(c)
		What.DRAW_PILE:
			cards = p.draw_pile.duplicate()
		_:
			var f := Callable()
			if curses_only:
				f = func(c: CardInstance): return c.is_curse()
			cards = await enc.choose_cards(p, piles, amount, "Destroy" if destroy else "Remove", ctx, false, f, ctx.card)
	var coins := 0
	for c in cards:
		await enc.trash_card(p, c, destroy)
		coins += coins_per_card + (c.get_cost() if gain_cost_as_coins else 0)
	if coins > 0:
		enc.change_coins(p, coins, ctx.source_name)


func is_cost() -> bool:
	return as_cost


func describe() -> String:
	var icon := "🔥" if destroy else "🗑"
	var verb := "Destroy" if destroy else "Remove"
	var t := ""
	match what:
		What.SELF: t = "%s this" % icon
		What.ALL_OTHER_HAND: t = "%s all other cards %s in hand" % [verb, icon]
		What.DRAW_PILE: t = "%s your deck %s" % [verb, icon]
		_:
			t = "%s %d %s%s" % [verb, amount, icon, " curse" if curses_only else ""]
			if piles == GameRules.PILE_HAND:
				t += " in hand"
	if coins_per_card > 0:
		t += ". Gain %d 🪙 for each" % coins_per_card
	if gain_cost_as_coins:
		t += ". Gain 🪙 equal to its cost"
	return t


func ai_score() -> float:
	var s := 0.3 if what == What.CHOOSE else 0.0
	if what == What.SELF:
		s = -0.5 if destroy else -0.2
	return s + coins_per_card * 0.8 + (1.0 if gain_cost_as_coins else 0.0)

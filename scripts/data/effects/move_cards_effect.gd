class_name MoveCardsEffect
extends Effect
## Move your cards between piles (no draw / discard triggers).
## amount = 0: every matching card; otherwise you choose `amount`.
## Examples: return all curses from the discard pile to your hand; move the
## curses in your deck to the bottom; put a card from your hand on top.

@export_flags("Hand:1", "Deck:2", "Discard:4") var from_piles: int = GameRules.PILE_DISCARD
@export var to_zone: GameRules.Zone = GameRules.Zone.HAND
@export var curses_only: bool = false
@export var amount: int = 0


func apply(ctx: EffectContext) -> void:
	var enc := ctx.encounter
	var p := ctx.owner
	var f := func(c: CardInstance): return not curses_only or c.is_curse()
	var cards: Array = []
	if amount <= 0:
		for pair in [[GameRules.PILE_HAND, p.hand], [GameRules.PILE_DRAW, p.draw_pile], [GameRules.PILE_DISCARD, p.discard]]:
			if from_piles & pair[0]:
				for c in pair[1]:
					if c != ctx.card and f.call(c):
						cards.append(c)
	else:
		cards = await enc.choose_cards(p, from_piles, amount, "Move", ctx, false, f, ctx.card)
	for c in cards:
		enc.move_card(p, c, to_zone)
	if not cards.is_empty():
		enc.log_line("  %s move %d card%s %s." % [p.display_name, cards.size(), "" if cards.size() == 1 else "s", _where()])


func _where() -> String:
	match to_zone:
		GameRules.Zone.HAND: return "to your hand"
		GameRules.Zone.DRAW_TOP: return "on top of your deck"
		GameRules.Zone.DRAW_BOTTOM: return "to the bottom of your deck"
		GameRules.Zone.DISCARD: return "to your discard pile"
	return "into your deck"


func _pile_name() -> String:
	if from_piles == GameRules.PILE_HAND: return "your hand"
	if from_piles == GameRules.PILE_DRAW: return "your deck"
	if from_piles == GameRules.PILE_DISCARD: return "the discard pile"
	return "your cards"


func describe() -> String:
	var what := "curses" if curses_only else "cards"
	if amount <= 0:
		return "Move all %s in %s %s" % [what, _pile_name(), _where()]
	return "Put %s from %s %s" % ["a card" if amount == 1 else "%d %s" % [amount, what], _pile_name(), _where()]


func ai_score() -> float:
	return 0.3

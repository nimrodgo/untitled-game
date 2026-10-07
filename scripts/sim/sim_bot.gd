class_name SimBot
extends RefCounted
## A simple greedy PLAYER bot used only by tools/simulate.gd for smoke/balance
## testing. Not used in the game (the enemy follows scripted intents).

const MIN_VALUE := 0.25
const MAX_BUYS_PER_ROUND := 4
## Verbs where the bot wants to get rid of its worst cards.
const BAD_VERBS := ["Discard", "Destroy", "Remove", "Transform", "Move"]


static func take_turn(enc: Encounter) -> void:
	var me := enc.player
	if not enc.is_player_turn():
		return
	for i in me.trinkets.size():
		if enc.can_use_trinket(i) and Effect.score_list(me.trinkets[i].current_effects()) > 0:
			enc.use_trinket(i)
			if not enc.is_player_turn():
				return
	for c in me.hand.duplicate():
		if not enc.is_player_turn():
			return
		if c.is_instant() and enc.can_play(c) and Effect.score_list(c.get_on_play()) > 0:
			enc.play_card(c)
	if not enc.is_player_turn():
		return

	var best_value := MIN_VALUE
	var best: Callable = Callable()
	for c in me.hand:
		if c.is_instant() or not enc.can_play(c):
			continue
		var v := Effect.score_list(c.get_on_play())
		if c.is_curse():
			v = 1.0   # playable curses (e.g. "play to remove") are worth clearing
		if v > best_value:
			best_value = v
			best = enc.play_card.bind(c)

	# Coins are the score, so buying only pays off with rounds left to use it.
	var future := float(enc.rounds_left() - 1) / float(maxi(1, enc.data.rounds))
	if me.buys_this_round < MAX_BUYS_PER_ROUND:
		for slot in enc.shop.cards.size():
			if not enc.can_buy_card(slot):
				continue
			var cd: CardData = enc.shop.cards[slot]
			var v := Effect.score_list(cd.on_buy) + Effect.score_list(cd.on_play) * future * 1.5 - cd.cost * 0.6
			if v > best_value:
				best_value = v
				best = enc.buy_card.bind(slot)
		for slot in enc.shop.items.size():
			if enc.can_buy_item(slot) and future > 0.4 and me.coins >= enc.item_price(enc.shop.items[slot]) + 3:
				best = enc.buy_item.bind(slot)
				break

	if best.is_valid():
		best.call()
	else:
		enc.pass_turn()


## Answers Encounter choices (set as Encounter.auto_chooser).
static func choose(req: ChoiceRequest) -> Array:
	match req.kind:
		ChoiceRequest.Kind.OPTIONS:
			var best := -1
			for i in req.candidates.size():
				if req.enabled.is_empty() or req.enabled[i]:
					best = i
					break
			return [maxi(best, 0)]
		ChoiceRequest.Kind.CARDS, ChoiceRequest.Kind.CARD_DATA:
			var cards: Array = req.candidates.duplicate()
			var bad: bool = req.verb in BAD_VERBS
			cards.sort_custom(func(a: CardInstance, b: CardInstance): return _value(a) < _value(b) if bad else _value(a) > _value(b))
			var n := req.min_count
			if bad and req.max_count > n:
				# Optional riddance: only curses.
				for c in cards.slice(n):
					if c.is_curse() and n < req.max_count:
						n += 1
			elif not bad:
				n = req.max_count
			return cards.slice(0, n)
	return req.candidates.slice(0, maxi(req.min_count, 1) if req.max_count > 0 else 0)


static func _value(c: CardInstance) -> float:
	if c.is_curse():
		return -5.0
	return Effect.score_list(c.get_on_play())

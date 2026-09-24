class_name SimBot
extends RefCounted
## A simple greedy PLAYER bot used only by tools/simulate.gd for smoke/balance
## testing. Not used in the game (the enemy follows scripted intents).

const MIN_VALUE := 0.25
const MAX_BUYS_PER_ROUND := 4


static func take_turn(enc: Encounter) -> void:
	var me := enc.player
	if not enc.is_player_turn():
		return
	for i in me.trinkets.size():
		if enc.can_use_trinket(i) and Effect.score_list(me.trinkets[i].current_effects()) > 0:
			enc.use_trinket(i)
	for c in me.hand.duplicate():
		if c.is_instant() and enc.can_play(c) and Effect.score_list(c.get_on_play()) > 0:
			enc.play_card(c)
	if not enc.is_player_turn():
		return

	var best_value := MIN_VALUE
	var best: Callable = Callable()
	for c in me.hand:
		if c.is_instant():
			continue
		var v := Effect.score_list(c.get_on_play())
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

	if best.is_valid():
		best.call()
	else:
		enc.pass_turn()

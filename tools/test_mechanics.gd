extends SceneTree
## Headless rules tests for the card mechanics (design/ideas.md).
## Run:  godot --headless --path . --script res://tools/test_mechanics.gd
## Prints PASS/FAIL per check and a summary; exits with code 1 on failure.

const ENC := "res://content/test/encounters/test_encounter.tres"
const LO := "res://content/test/loadouts/test_loadout.tres"

var fails := 0
var checks := 0


func _init() -> void:
	var data: EncounterData = load(ENC)
	_smoke_every_card(data)
	_smoke_every_item_and_trinket(data)
	_rules(data)
	print("\n%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ helpers

func _card(id: String) -> CardData:
	for p in ["res://content/test/cards/%s.tres", "res://content/test/curses/%s.tres"]:
		if ResourceLoader.exists(p % id):
			return load(p % id)
	push_error("no card " + id)
	return null


func _item(id: String) -> ItemData:
	return load("res://content/test/items/%s.tres" % id)


func _trinket(id: String) -> TrinketData:
	return load("res://content/test/trinkets/%s.tres" % id)


## A started encounter with a known deck; the enemy never acts (0 actions)
## unless `enemy_acts`.
func _enc(deck: Array, auto := true, enemy_acts := false) -> Encounter:
	var data: EncounterData = load(ENC).duplicate()
	data.rng_seed = 12345
	if not enemy_acts:
		var ed: EnemyData = data.enemy.duplicate()
		ed.actions_per_round = 0
		data.enemy = ed
	var lo := LoadoutData.new()
	lo.starting_coins = 10
	var d: Array[CardData] = []
	for id in deck:
		d.append(_card(id))
	lo.starting_deck = d
	var e := Encounter.new(data, lo)
	if auto:
		e.auto_chooser = SimBot.choose
	e.start()
	return e


func _in_hand(e: Encounter, id: String) -> CardInstance:
	for c in e.player.hand:
		if c.data.id == StringName(id):
			return c
	return null


## Put a fresh copy of card `id` into the hand.
func _give(e: Encounter, id: String) -> CardInstance:
	var c := CardInstance.new(_card(id))
	e.player.hand.append(c)
	return c


func _check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


## Every card instance is in exactly one place.
func _consistent(e: Encounter, what: String) -> void:
	var p := e.player
	var seen := {}
	var ok := true
	for pile in [p.hand, p.draw_pile, p.discard, p.in_play, p.removed, p.destroyed]:
		for c in pile:
			if seen.has(c):
				ok = false
			seen[c] = true
	_check(ok, what + ": a card is in two piles")


# -------------------------------------------------------------------- smoke

func _smoke_every_card(data: EncounterData) -> void:
	for cd in data.card_pool:
		var e := _enc(["example2", "example2", "example1", "dead_weight", "leaky_purse", "example1", "example2", "barnacle"])
		e.player.coins = 20
		var t := TrinketInstance.new(_trinket("coin_trinket"))
		t.used = true
		e.player.trinkets.append(t)
		e.player.destroyed.append(CardInstance.new(_card("example1")))
		e.player.removed.append(CardInstance.new(_card("example2")))
		e.player.discard.append(CardInstance.new(_card("driftwood")))
		var c := _give(e, String(cd.id))
		var ok := e.play_card(c)
		_check(ok, "%s: playable" % cd.id)
		_check(not e.is_busy(), "%s: action finished (not stuck)" % cd.id)
		_consistent(e, String(cd.id))
		# Keep going to the end of the encounter.
		var steps := 0
		while not e.is_over and steps < 200:
			if e.active == e.enemy:
				e.enemy_act()
			else:
				SimBot.take_turn(e)
			steps += 1
		_check(e.is_over, "%s: encounter finishes" % cd.id)


func _smoke_every_item_and_trinket(data: EncounterData) -> void:
	for it in data.item_pool:
		var e := _enc(["example2", "dead_weight", "example1", "sift", "driftwood", "prune", "spring", "example2", "hold", "study"])
		e.player.items.append(ItemInstance.new(it))
		var steps := 0
		while not e.is_over and steps < 300:
			if e.active == e.enemy:
				e.enemy_act()
			else:
				SimBot.take_turn(e)
			steps += 1
		_check(e.is_over, "item %s: encounter finishes" % it.id)
		_consistent(e, "item %s" % it.id)
	for td in data.trinket_pool:
		for lv in td.levels.size():
			var e := _enc(["example2", "dead_weight", "example1", "example1", "example2", "example2", "example1"])
			var t := TrinketInstance.new(td)
			t.level = lv
			e.player.trinkets.append(t)
			_check(e.use_trinket(0), "trinket %s L%d usable" % [td.id, lv + 1])
			_check(not e.is_busy(), "trinket %s L%d finished" % [td.id, lv + 1])
			_consistent(e, "trinket %s" % td.id)


# -------------------------------------------------------------------- rules

func _rules(_data: EncounterData) -> void:
	var e: Encounter
	var c: CardInstance

	# Costs: discard-a-card cost needs another card; pay needs coins.
	e = _enc(["example2", "example2", "example2", "example2", "example2"])
	e.player.hand.clear()
	c = _give(e, "cycle")
	_check(not e.can_play(c), "Cycle unplayable with an empty rest of hand")
	_give(e, "example2")
	_check(e.can_play(c), "Cycle playable with another card")
	c = _give(e, "invest")
	e.player.coins = 1
	_check(not e.can_play(c), "Invest unplayable with 1 coin")
	# "all" works on 0: Liquidate with nothing else in hand
	e = _enc(["example2", "example2", "example2", "example2", "example2"])
	e.player.hand.clear()
	c = _give(e, "liquidate")
	_check(e.can_play(c), "Liquidate playable with no other cards")

	# Unplayable curse.
	e = _enc(["dead_weight", "example2", "example2", "example2", "example2"])
	_check(not e.can_play(_in_hand(e, "dead_weight")), "C1 unplayable")
	# C3 plays as a normal action and removes itself.
	e = _enc(["driftwood", "example2", "example2", "example2", "example2"], true, true)
	c = _in_hand(e, "driftwood")
	_check(e.play_card(c), "C3 playable")
	_check(e.player.removed.has(c), "C3 removed itself")
	_check(e.active == e.enemy, "C3 is a normal action (enemy answers)")
	# C4: lose 2 at end of turn if in hand.
	e = _enc(["leaky_purse", "example1", "example1", "example1", "example1"])
	var before := e.player.coins
	e.pass_turn()
	_check(e.player.coins == before - 2, "C4 in hand costs 2 at end of turn (%d -> %d)" % [before, e.player.coins])

	# Patience option 2: pass right away, enemy doesn't answer, +3.
	e = _enc(["example1", "example1", "example1", "example1", "example1"], false, true)
	c = _give(e, "patience")
	before = e.player.coins
	e.play_card(c)
	_check(e.pending_choice != null and e.pending_choice.kind == ChoiceRequest.Kind.OPTIONS, "Patience asks OR")
	_check(not e.is_player_turn(), "no actions while a choice is pending")
	e.submit_choice([1])
	_check(e.round_num == 2 and e.player.coins == before + 3, "Patience pass: round 2, +3 (round %d)" % e.round_num)
	_check(e.enemy_actions_left == e.data.enemy.actions_per_round, "enemy didn't answer the passing action")

	# Manual in-hand choice: Sift draws 2, then discard 2 chosen.
	e = _enc(["example1", "example1", "example1", "example1", "example1", "example2", "example2", "example2"], false)
	c = _give(e, "sift")
	e.play_card(c)
	var req := e.pending_choice
	_check(req != null and req.hand_only and req.min_count == 2, "Sift: pick 2 in hand")
	_check(not e.submit_choice([req.candidates[0]]), "wrong number of picks is rejected")
	e.submit_choice(req.candidates.slice(0, 2))
	_check(e.pending_choice == null and e.player.discard.size() == 2, "Sift discarded 2")

	# Destroy exactly N unless nothing to pick; mixed piles -> not hand_only.
	e = _enc(["example1", "example1", "example1", "example1", "example1", "example2"], false)
	c = _give(e, "pawn")
	e.play_card(c)
	_check(e.pending_choice and e.pending_choice.hand_only, "Pawn picks in hand")
	var pick: CardInstance = e.pending_choice.candidates[0]
	before = e.player.coins
	e.submit_choice([pick])
	_check(e.player.destroyed.has(pick) and e.player.coins == before + pick.get_cost(), "Pawn destroys, gains its cost")
	c = _give(e, "purge")
	e.play_card(c)
	e.submit_choice([1])   # Remove 2
	_check(e.pending_choice and not e.pending_choice.hand_only and e.pending_choice.min_count == 2,
		"Purge remove 2 from deck/hand/discard -> popup")
	e.submit_choice(e.pending_choice.candidates.slice(0, 2))
	_check(e.player.removed.size() == 2, "Purge removed 2")

	# Hold: retained card stays; next hand = 5 + retained.
	e = _enc(["example1", "example1", "example1", "example1", "example1", "example2", "example2", "example2", "example2", "example2", "example2"], false)
	c = _give(e, "hold")
	e.play_card(c)
	var kept: CardInstance = e.pending_choice.candidates[0]
	e.submit_choice([kept])
	e.pass_turn()
	_check(e.player.hand.has(kept) and e.player.hand.size() == 6, "Hold: retained card + 5 new (hand %d)" % e.player.hand.size())

	# Echo: next card played twice (counts as 2 plays + Echo = 3).
	e = _enc(["example1", "example1", "example1", "example1", "example1"])
	e.play_card(_give(e, "echo"))
	before = e.player.coins
	e.play_card(_give(e, "snowball"))
	_check(e.player.coins == before + 2 + 4, "Echo+P1: 2 then 4 (got %d)" % (e.player.coins - before))
	_check(e.player.cards_played_this_turn == 3, "replays count as plays")

	# Meditate with no other plays: extra round, destroyed.
	e = _enc(["example1", "example1", "example1", "example1", "example1"], true, true)
	c = _give(e, "meditate")
	e.play_card(c)
	_check(e.total_rounds() == 4 and e.round_num == 2, "Meditate: extra round, passed")
	_check(e.player.destroyed.has(c), "Meditate destroyed itself")
	# ...but not after playing another card.
	e = _enc(["example2", "example1", "example1", "example1", "example1"])
	e.play_card(_in_hand(e, "example2"))
	e.play_card(_give(e, "meditate"))
	_check(e.total_rounds() == 3, "Meditate after a play: no extra round")

	# Spring: discarded by an effect -> draw 2; end-of-round cleanup doesn't.
	e = _enc(["example1", "example1", "example1", "example1", "example1", "example2", "example2", "example2", "example2"], false)
	var spring := _give(e, "spring")
	e.play_card(_give(e, "study"))   # draw 3, discard 1
	var n := e.player.hand.size()
	e.submit_choice([spring])
	_check(e.player.hand.size() == n - 1 + 2, "Spring discarded -> draw 2")
	e = _enc(["example1", "example1", "example1", "example1", "example1", "example2", "example2", "example2", "example2", "example2"])
	_give(e, "spring")
	var drawn_before := e.player.cards_drawn_this_turn
	e.pass_turn()
	_check(e.round_num == 2, "cleanup doesn't trigger Spring (no crash)")

	# Items.
	e = _enc(["example1", "example1", "example1", "example1", "example1", "example1", "example1"])
	e.player.items.append(ItemInstance.new(_item("big_hands")))
	e.pass_turn()
	_check(e.player.hand.size() == 6 and e.player.cards_drawn_this_turn == 0, "Big Hands: 6 cards, not counted as drawn")
	e = _enc(["example1", "example1", "example1", "example1", "example1"])
	e.player.items.append(ItemInstance.new(_item("grindstone")))
	before = e.player.coins
	e.play_card(_give(e, "sift"))
	_check(e.player.coins == before + 4, "Grindstone: +2 per discard")
	e = _enc(["example2", "example2", "example2", "example2", "example2"])
	e.player.items.append(ItemInstance.new(_item("furnace")))
	c = _in_hand(e, "example2")
	e.play_card(c)
	var c2 := _in_hand(e, "example2")
	e.play_card(c2)
	_check(e.player.destroyed.has(c) and not e.player.destroyed.has(c2), "Furnace destroys only the first play")
	e = _enc(["example2", "example2", "example2", "example2", "example2"])
	e.player.items.append(ItemInstance.new(_item("echo_chamber")))
	before = e.player.coins
	e.play_card(_in_hand(e, "example2"))
	e.play_card(_in_hand(e, "example2"))
	_check(e.player.coins == before + 3, "Echo Chamber: first card twice (+%d)" % (e.player.coins - before))
	e = _enc(["dead_weight", "example1", "example1", "example1", "example1", "dead_weight"])
	e.player.items.append(ItemInstance.new(_item("cursed_luck")))
	e.pass_turn()
	_check(e.player.coins == 10 + 2 * _count_id(e.player.hand, "dead_weight"), "Cursed Luck fires on opening-hand curses")
	e = _enc(["example1", "example1", "example1", "example1", "example1", "example2", "example2"], false)
	e.player.items.append(ItemInstance.new(_item("second_look")))
	e.play_card(_in_hand(e, "example1"))   # draw 2
	_check(e.pending_choice != null and e.pending_choice.kind == ChoiceRequest.Kind.OPTIONS, "Second Look offers a redraw")
	e.submit_choice([1])   # keep
	_check(e.pending_choice != null, "declined -> still offered for the next draw")
	e.submit_choice([0])   # redraw
	_check(e.pending_choice == null, "used -> disabled for the turn")
	e = _enc(["example1", "example1", "example1", "example1", "example1", "example2"], false)
	e.player.items.append(ItemInstance.new(_item("pocket")))
	e.pass_turn()
	_check(e.pending_choice != null and e.pending_choice.min_count == 0, "Pocket: optional retain at end of turn")
	var keep: CardInstance = e.pending_choice.candidates[0]
	e.submit_choice([keep])
	_check(e.player.hand.has(keep) and e.round_num == 2, "Pocket kept a card")

	# Rush Order: next buy goes to hand.
	e = _enc(["example1", "example1", "example1", "example1", "example1"])
	e.play_card(_give(e, "rush_order"))
	var slot := -1
	for i in e.shop.cards.size():
		if e.shop.cards[i] != null:
			slot = i
			break
	var hand_n := e.player.hand.size()
	e.buy_card(slot)
	_check(e.player.hand.size() == hand_n + 1, "Rush Order: bought card drawn")

	# Scorched Earth: destroys itself and the draw pile.
	e = _enc(["example1", "example1", "example1", "example1", "example1", "example2", "example2"])
	var deck_n := e.player.draw_pile.size()
	e.play_card(_give(e, "scorched_earth"))
	_check(e.player.draw_pile.is_empty() and e.player.destroyed.size() == deck_n + 1, "Scorched Earth")

	# Binge: no more draws this turn.
	e = _enc(["example1", "example1", "example1", "example1", "example1", "example2", "example2", "example2", "example2", "example2"])
	e.play_card(_give(e, "binge"))
	n = e.player.hand.size()
	e.play_card(_in_hand(e, "example1"))
	_check(e.player.hand.size() == n - 1, "Binge blocks further draws")


	# Curses added by your own cards go into YOUR deck; enemy "lose" hits you.
	e = _enc(["example1", "example1", "example1", "example1", "example1"], true, true)
	var deck_before := e.player.draw_pile.size()
	e.play_card(_give(e, "cursed_coin"))
	_check(_count_id(e.player.draw_pile, "barnacle") == 1 and e.player.draw_pile.size() == deck_before + 1, "Cursed Coin: C2 shuffled into your deck")
	while e.current_intent().display_name != "Toll":
		e.enemy.intent_index += 1
	before = e.player.coins
	var enemy_before := e.enemy.coins
	e.active = e.enemy
	e.enemy_act()
	_check(e.player.coins == before - 1 and e.enemy.coins == enemy_before, "enemy Toll: you lose 1")


	_trinket_shop_rules()


## Trinkets: 2 in the shop, max 3 owned, buy a duplicate to upgrade, sell for
## half of everything paid (free action), maxed ones leave the shop.
func _trinket_shop_rules() -> void:
	var e := _enc(["example1", "example1", "example1", "example1", "example1"], true, true)
	_check(e.shop.trinkets.size() == 2 and e.shop.items.size() == 1, "shop: 2 trinket slots, 1 item slot")
	_check(e.shop.trinkets[0] != null and e.shop.trinkets[1] != null and e.shop.trinkets[0] != e.shop.trinkets[1],
		"shop: two different trinkets")
	e.player.coins = 50
	# Buy a new one (Forge: 3 levels) into slot 0.
	e.shop.trinkets[0] = _trinket("forge")
	var td: TrinketData = e.shop.trinkets[0]
	var cost := td.cost
	_check(e.can_buy_trinket(0) and e.buy_trinket(0), "buy a new trinket")
	_check(e.player.coins == 50 - cost and e.player.trinkets.size() == 1, "new trinket costs its price")
	while e.active == e.enemy:
		e.enemy_act()
	# Put the same trinket back in the shop: buying it upgrades yours.
	e.shop.trinkets[1] = td
	var up := e.trinket_buy_cost(td)
	_check(up == td.levels[1].upgrade_cost, "duplicate costs the next upgrade cost (%d)" % up)
	var before := e.player.coins
	_check(e.buy_trinket(1), "buy the duplicate")
	_check(e.player.trinkets.size() == 1 and e.player.trinkets[0].level == 1 and e.player.coins == before - up,
		"duplicate upgraded the owned trinket (level %d)" % e.player.trinkets[0].level)
	_check(e.player.trinkets[0].paid == cost + up, "paid tracks purchase + upgrades")
	while e.active == e.enemy:
		e.enemy_act()
	# Max level: no longer offered, can't be bought.
	e.player.trinkets[0].level = td.levels.size() - 1
	e.shop.trinkets[1] = td
	_check(not e.can_buy_trinket(1), "max-level duplicate can't be bought")
	var seen_max := false
	for i in 40:
		e.shop.restock_trinkets()
		if e.shop.trinkets.has(td):
			seen_max = true
	_check(not seen_max, "max-level owned trinket never appears in the shop")
	# Owned, not maxed: shows up more often than others.
	e.player.trinkets[0].level = 0
	var owned_seen := 0
	var other_seen := 0
	for i in 400:
		e.shop.restock_trinkets()
		for t in e.shop.trinkets:
			if t == td: owned_seen += 1
			elif t != null: other_seen += 1
	var pool_n := e.data.trinket_pool.size()
	_check(float(owned_seen) > float(other_seen) / float(pool_n - 1) * 1.4, "owned trinkets are favoured (%d vs %.0f avg)" % [owned_seen, float(other_seen) / float(pool_n - 1)])

	# Three slots max: a fourth NEW trinket can't be bought.
	e = _enc(["example1", "example1", "example1", "example1", "example1"], true, true)
	e.player.coins = 99
	for i in 3:
		var t := TrinketInstance.new(e.data.trinket_pool[i])
		e.player.trinkets.append(t)
	var fresh := -1
	for s in e.shop.trinkets.size():
		e.shop.trinkets[s] = e.data.trinket_pool[5 + s]
		fresh = s
	_check(not e.can_buy_trinket(fresh), "full slots: can't buy a new trinket")
	# ...but an upgrade of an owned one is fine.
	e.shop.trinkets[0] = e.data.trinket_pool[1]
	_check(e.can_buy_trinket(0), "full slots: upgrading an owned trinket is allowed")

	# Selling: half of everything paid, rounded down, free action, frees a slot.
	var t0: TrinketInstance = e.player.trinkets[1]
	t0.paid = 7
	before = e.player.coins
	var acts_before := e.enemy_actions_left
	_check(e.can_sell_trinket(1) and e.sell_trinket(1), "sell a trinket")
	_check(e.player.coins == before + 3, "sold for half of 7 rounded down = 3 (got %d)" % (e.player.coins - before))
	_check(e.player.trinkets.size() == 2 and e.is_player_turn() and e.enemy_actions_left == acts_before,
		"selling is a free action (enemy doesn't answer)")
	_check(e.can_buy_trinket(fresh), "a slot opened up for a new trinket")


func _count_id(arr: Array, id: String) -> int:
	var n := 0
	for c in arr:
		if c.data.id == StringName(id):
			n += 1
	return n

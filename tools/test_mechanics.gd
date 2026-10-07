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
	_encounter_rules()
	_enhancement_rules()
	_deck_cycle_rules()
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
func _enc(deck: Array, auto := true, enemy_acts := false, path := ENC) -> Encounter:
	var data: EncounterData = load(path).duplicate()
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
	for pile in [p.hand, p.draw_pile, p.discard, p.removed, p.destroyed]:
		for c in pile:
			if seen.has(c):
				ok = false
			seen[c] = true
	_check(ok, what + ": a card is in two piles")


# -------------------------------------------------------------------- smoke

func _smoke_every_card(data: EncounterData) -> void:
	for cd in data.get_card_pool():
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
	for it in data.get_item_pool():
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
	for td in data.get_trinket_pool():
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
	_check(e.pending_choice == null and e.player.discard.size() == 3 and e.player.discard.has(c), "Sift discarded 2, and itself went to the discard pile")

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
	e = _enc(["example1", "example1", "example1", "example1", "example1", "example2", "example2", "example2", "example2", "example2"], false)
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
	e = _enc(["example1", "example1", "example1", "example1", "example1"])
	e.player.items.append(ItemInstance.new(_item("shredder")))
	e.play_card(_give(e, "sift"))
	_check(e.player.removed.size() == 2, "Shredder: both discarded cards are removed")
	e = _enc(["example1", "example1", "example1", "example1", "example1"], true, true)
	e.shop.cards[0] = _card("all_in")
	var base_price: int = e.shop.cards[0].cost
	_check(e.card_price(e.player, base_price) == base_price, "no discount without Needful")
	e.player.items.append(ItemInstance.new(_item("needful")))
	_check(e.card_price(e.player, base_price) == 0, "Needful: market cards cost 0")
	e.player.coins = 0
	_check(e.can_buy_card(0), "Needful: buy with 0 coins")
	e.buy_card(0)
	var curse_n := 0
	for pile in [e.player.draw_pile, e.player.hand, e.player.discard]:
		for cc in pile:
			if cc.is_curse():
				curse_n += 1
	_check(e.player.coins == 0 and curse_n == 1, "Needful: free buy adds exactly one random curse (%d)" % curse_n)
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


## Trinkets: 1 in the shop, max 3 owned, buy a duplicate to upgrade, sell for
## half of everything paid (free action), maxed ones leave the shop.
func _trinket_shop_rules() -> void:
	var e := _enc(["example1", "example1", "example1", "example1", "example1"], true, true)
	_check(e.shop.trinkets.size() == 1 and e.shop.items.size() == 1, "shop: 1 trinket slot, 1 item slot")
	_check(e.shop.trinkets[0] != null, "shop: the trinket slot is filled")
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
	e.shop.trinkets[0] = td
	var up := e.trinket_buy_cost(td)
	_check(up == td.levels[1].upgrade_cost, "duplicate costs the next upgrade cost (%d)" % up)
	var before := e.player.coins
	e.player.trinkets[0].used = true
	_check(not e.can_use_trinket(0), "a used trinket can't be used again")
	_check(e.buy_trinket(0), "buy the duplicate")
	_check(not e.player.trinkets[0].used, "upgrading refreshes a used trinket")
	_check(e.player.trinkets.size() == 1 and e.player.trinkets[0].level == 1 and e.player.coins == before - up,
		"duplicate upgraded the owned trinket (level %d)" % e.player.trinkets[0].level)
	_check(e.player.trinkets[0].paid == cost + up, "paid tracks purchase + upgrades")
	while e.active == e.enemy:
		e.enemy_act()
	# Max level: no longer offered, can't be bought.
	e.player.trinkets[0].level = td.levels.size() - 1
	e.shop.trinkets[0] = td
	_check(not e.can_buy_trinket(0), "max-level duplicate can't be bought")
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
	var pool_n := e.data.get_trinket_pool().size()
	_check(float(owned_seen) > float(other_seen) / float(pool_n - 1) * 1.4, "owned trinkets are favoured (%d vs %.0f avg)" % [owned_seen, float(other_seen) / float(pool_n - 1)])

	# Three slots max: a fourth NEW trinket can't be bought.
	e = _enc(["example1", "example1", "example1", "example1", "example1"], true, true)
	e.player.coins = 99
	for i in 3:
		var t := TrinketInstance.new(e.data.get_trinket_pool()[i])
		e.player.trinkets.append(t)
	var fresh := -1
	for s in e.shop.trinkets.size():
		e.shop.trinkets[s] = e.data.get_trinket_pool()[5 + s]
		fresh = s
	_check(not e.can_buy_trinket(fresh), "full slots: can't buy a new trinket")
	# ...but an upgrade of an owned one is fine.
	e.shop.trinkets[0] = e.data.get_trinket_pool()[1]
	_check(e.can_buy_trinket(0), "full slots: upgrading an owned trinket is allowed")
	e.shop.trinkets[0] = e.data.get_trinket_pool()[5 + 0]

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


# ------------------------------------------------------- the 5 encounters

const ENC_DIR := "res://content/test/encounters/%s.tres"
const THEMES := {
	"hags_hex": [CardSets.Id.TRIM, CardSets.Id.CURSE_SYNERGY],
	"ink_cloud": [CardSets.Id.DRAW, CardSets.Id.DISCARD],
	"toll_booth": [CardSets.Id.MARKET, CardSets.Id.DRAW],
	"loan_shark": [CardSets.Id.CURSE_SYNERGY, CardSets.Id.MARKET],
	"clutter": [CardSets.Id.DISCARD, CardSets.Id.TRIM],
}
const DECK5 := ["example1", "example1", "example1", "example1", "example1"]


## An encounter whose enemy is about to resolve intent `idx`; resolves it.
func _enemy_does(e: Encounter, intent_name: String) -> void:
	while e.current_intent().display_name != intent_name:
		e.enemy.intent_index += 1
	e.active = e.enemy
	e.enemy_act()


func _encounter_rules() -> void:
	for file in THEMES:
		var path: String = ENC_DIR % file
		var data: EncounterData = load(path)
		var allowed: Array = THEMES[file].duplicate()
		allowed.append(CardSets.Id.UTILITY)
		allowed.append(CardSets.Id.COINS)
		var only_allowed := true
		var seen := {}
		for pool in [data.get_card_pool(), data.get_item_pool(), data.get_trinket_pool()]:
			for r in pool:
				seen[r.card_set] = true
				if not allowed.has(r.card_set):
					only_allowed = false
		_check(only_allowed, "%s: sells only its 2 sets + Utility + Coins" % file)
		var all_present := true
		for s in allowed:
			all_present = all_present and seen.has(s)
		_check(all_present, "%s: every one of its 4 sets is for sale" % file)
		_check(data.trinket_slots == 1 and data.item_slots == 1, "%s: 1 trinket slot, 1 item slot" % file)
		_check(data.enemy != null and data.enemy.intents.size() == 3, "%s: enemy with 3 intents" % file)
		# A bot plays it end to end without hanging.
		var lo: LoadoutData = load(LO)
		var finished := true
		for i in 3:
			var enc := Encounter.new(data, lo)
			enc.auto_chooser = SimBot.choose
			enc.start()
			var steps := 0
			while not enc.is_over and steps < 2000:
				if enc.active == enc.enemy:
					enc.enemy_act()
				else:
					SimBot.take_turn(enc)
				steps += 1
			finished = finished and enc.is_over
		_check(finished, "%s: a bot plays it to the end" % file)

	# card_sets fills the pools; a manual pool adds on top (and raises odds).
	var plain := EncounterData.new()
	_check(plain.get_card_pool().is_empty(), "no card_sets and no pool: nothing to sell")
	plain.card_sets.assign([CardSets.Id.DRAW])
	var base_n := plain.get_card_pool().size()
	var only_ok := true
	for c in plain.get_card_pool():
		only_ok = only_ok and [CardSets.Id.DRAW, CardSets.Id.UTILITY, CardSets.Id.COINS].has(c.card_set)
	_check(base_n > 0 and only_ok, "card_sets [Draw]: sells Draw + Utility + Coins only (%d cards)" % base_n)
	plain.card_pool.assign([_card("hex"), _card("hex")])
	_check(plain.get_card_pool().size() == base_n + 2, "a manual pool is added on top of the sets")

	# A. Sea Hag
	var e := _enc(DECK5, true, true, ENC_DIR % "hags_hex")
	var deck_n := e.player.draw_pile.size()
	_enemy_does(e, "Hex")
	_check(_count_id(e.player.draw_pile, "leaky_purse") == 1 and e.player.draw_pile.size() == deck_n + 1,
		"Sea Hag: Hex shuffles Leaky Purse into YOUR deck")
	e.active = e.enemy
	_enemy_does(e, "Foul Brew")
	var curses := 0
	for c in e.player.draw_pile:
		if c.data.curse:
			curses += 1
	_check(curses == 2 and _count_id(e.player.draw_pile, "barnacle") == 0,
		"Sea Hag: Foul Brew adds a random curse, never the permanent Barnacle")
	var coins := e.player.coins
	e.active = e.enemy
	_enemy_does(e, "Tithe")
	_check(e.player.coins == coins - 1, "Sea Hag: Tithe, you lose 1")

	# B. Cuttlefish
	e = _enc(DECK5, true, true, ENC_DIR % "ink_cloud")
	var hand_n := e.player.hand.size()
	_enemy_does(e, "Ink Spray")
	_check(e.player.hand.size() == hand_n - 1 and e.player.discard.size() == 1, "Cuttlefish: Ink Spray discards 1 at random")
	e.active = e.enemy
	_check(not e.player.draw_locked, "Cuttlefish: draws are open before Murk")
	_enemy_does(e, "Murk")
	_check(e.player.draw_locked and not e.enemy.draw_locked, "Cuttlefish: Murk locks YOUR draws")
	hand_n = e.player.hand.size()
	e.draw_cards(e.player, 2, false, false)
	_check(e.player.hand.size() == hand_n, "Cuttlefish: no cards drawn while locked")
	e.active = e.enemy
	e.player.coins = 5
	_enemy_does(e, "Pinch")
	_check(e.player.coins == 4 and e.enemy.coins == 1, "Cuttlefish: Pinch steals 1")

	# C. Barracuda: Toll on buys (once a round), snatches.
	e = _enc(DECK5, true, true, ENC_DIR % "toll_booth")
	e.player.coins = 40
	_check(e.enemy.items.size() == 1 and e.enemy.items[0].data.id == &"toll", "Barracuda owns the Toll")
	var s1 := _first_card_slot(e)
	var cost1: int = e.shop.cards[s1].cost
	var before := e.player.coins
	e.buy_card(s1)
	_check(e.player.coins == before - cost1 - 1, "Barracuda: the first buy of the round costs 1 extra")
	while e.active == e.enemy:
		e.enemy_act()
	var s2 := _first_card_slot(e)
	var cost2: int = e.shop.cards[s2].cost
	before = e.player.coins
	e.buy_card(s2)
	_check(e.player.coins == before - cost2, "Barracuda: the Toll is once per round")
	e = _enc(DECK5, true, true, ENC_DIR % "toll_booth")
	var filled := _filled_cards(e)
	var cheapest := 99
	var priciest := -1
	for cd in e.shop.cards:
		if cd != null:
			cheapest = mini(cheapest, cd.cost)
			priciest = maxi(priciest, cd.cost)
	_enemy_does(e, "Snatch")
	_check(_filled_cards(e) == filled - 1, "Barracuda: Snatch removes a market card")
	var left_min := 99
	for cd in e.shop.cards:
		if cd != null:
			left_min = mini(left_min, cd.cost)
	_check(left_min >= cheapest, "Barracuda: Snatch took a cheapest card")
	e.active = e.enemy
	_enemy_does(e, "Grab")
	_check(_filled_cards(e) == filled - 2, "Barracuda: Grab removes another market card")

	# D. Loan Shark
	e = _enc(DECK5, true, true, ENC_DIR % "loan_shark")
	_enemy_does(e, "Loan")
	_check(e.player.draw_pile.back().data.id == &"leaky_purse", "Loan Shark: Loan puts Leaky Purse on top of your deck")
	e.active = e.enemy
	coins = e.player.coins
	_enemy_does(e, "Interest")
	_check(e.player.coins == coins - 2, "Loan Shark: Interest, you lose 2")
	e.active = e.enemy
	filled = _filled_cards(e)
	_enemy_does(e, "Repo")
	_check(_filled_cards(e) == filled - 1, "Loan Shark: Repo removes a market card")

	# E. Hagfish
	e = _enc(DECK5, true, true, ENC_DIR % "clutter")
	hand_n = e.player.hand.size()
	_enemy_does(e, "Slime")
	_check(e.player.hand.size() == hand_n + 1 and _count_id(e.player.hand, "dead_weight") == 1,
		"Hagfish: Slime adds a Dead Weight to your HAND")
	e.active = e.enemy
	hand_n = e.player.hand.size()
	_enemy_does(e, "Squeeze")
	_check(e.player.hand.size() == hand_n - 1, "Hagfish: Squeeze discards 1 at random")


func _first_card_slot(e: Encounter) -> int:
	for i in e.shop.cards.size():
		if e.shop.cards[i] != null:
			return i
	return -1


func _filled_cards(e: Encounter) -> int:
	var n := 0
	for cd in e.shop.cards:
		if cd != null:
			n += 1
	return n


# ------------------------------------------------------------ enhancements

func _enh(id: String) -> EnhancementData:
	return load("res://content/test/enhancements/%s.tres" % id)


## A card from `deck`'s data with enhancement `enh_id` in the hand.
func _give_enh(e: Encounter, card_id: String, enh_id: String) -> CardInstance:
	var c := _give(e, card_id)
	c.enhancements.append(_enh(enh_id))
	return c


func _all_count(e: Encounter, id: String) -> int:
	var n := 0
	for pile in [e.player.hand, e.player.draw_pile, e.player.discard]:
		n += _count_id(pile, id)
	return n


func _enhancement_rules() -> void:
	# One enhancement per sold set, each in its own set.
	var sets := {}
	for en in ContentLibrary.enhancements():
		sets[en.card_set] = en.display_name
	for s in [CardSets.Id.COINS, CardSets.Id.DRAW, CardSets.Id.DISCARD, CardSets.Id.TRIM,
			CardSets.Id.RETAIN, CardSets.Id.UTILITY, CardSets.Id.MARKET, CardSets.Id.CURSE_SYNERGY]:
		_check(sets.has(s), "enhancement for set %s exists" % CardSets.display_name(s))

	# Coins: +2 coins on play.
	var e := _enc(DECK5)
	var c := _give(e, "example1")
	var before := e.player.coins
	e.play_card(c)
	var plain := e.player.coins - before
	e = _enc(DECK5)
	c = _give_enh(e, "example1", "gilded")
	before = e.player.coins
	e.play_card(c)
	_check(e.player.coins - before == plain + 2, "Gilded: +2 coins on play (%d vs %d)" % [e.player.coins - before, plain])
	_check(c.play_text().contains("+2"), "Gilded: card text shows the extra coins")

	# Draw: one extra card on play.
	e = _enc(DECK5 + DECK5)
	c = _give(e, "example1")
	var pile := e.player.draw_pile.size()
	e.play_card(c)
	var plain_drawn := pile - e.player.draw_pile.size()
	e = _enc(DECK5 + DECK5)
	c = _give_enh(e, "example1", "insight")
	pile = e.player.draw_pile.size()
	e.play_card(c)
	_check(pile - e.player.draw_pile.size() == plain_drawn + 1, "Insight: draws 1 extra card on play")

	# Discard: when discarded, it comes back to your hand.
	e = _enc(DECK5 + DECK5)
	c = _give_enh(e, "example1", "boomerang")
	e.discard_cards(e.player, [c])
	_check(e.player.hand.has(c) and not e.player.discard.has(c), "Boomerang: a discarded card returns to hand")
	_consistent(e, "Boomerang")
	var plain_c := _give(e, "example1")
	e.discard_cards(e.player, [plain_c])
	_check(e.player.discard.has(plain_c), "Boomerang: only the enhanced card returns")
	e.player.draw_locked = true
	e.discard_cards(e.player, [c])
	_check(e.player.discard.has(c), "Boomerang: stays discarded while draws are locked")
	# End-of-round cleanup is not a discard.
	e = _enc(DECK5 + DECK5, false)
	c = _give_enh(e, "example1", "boomerang")
	e.pass_turn()
	_check(e.player.discard.has(c) or e.player.hand.has(c) == false, "Boomerang: end-of-round cleanup still discards it")

	# Trim: buying it destroys the chosen card immediately (not when played).
	e = _enc(DECK5 + DECK5, true, false, ENC_DIR % "clutter")
	e.shop.enhancements[0] = _enh("fleeting")
	c = e.player.hand[0]
	var keep_c: CardInstance = e.player.hand[1]
	var coins_before := e.player.coins
	_check(e.can_buy_enhancement(0, c), "Fleeting: can be bought with a card in hand")
	_check(e.buy_enhancement(0, c), "Fleeting: buy_enhancement succeeds")
	_check(e.player.destroyed.has(c) and not e.player.hand.has(c), "Fleeting: the card is destroyed the moment you buy it")
	_check(c.enhancements.is_empty() and e.player.hand.has(keep_c), "Fleeting: nothing is attached, other cards untouched")
	_check(e.player.coins == coins_before - 3, "Fleeting: pays 3 coins")
	_check(e.shop.enhancements[0] == null, "Fleeting: the slot is empty until the next round")
	_consistent(e, "Fleeting")
	_check(e.is_player_turn() or e.active == e.enemy or e.round_num > 1, "Fleeting: the purchase resolves (turn not stuck)")
	# A plain play never destroys anything.
	e = _enc(DECK5 + DECK5)
	c = _give(e, "example1")
	e.play_card(c)
	_check(e.player.discard.has(c) and e.player.destroyed.is_empty(), "plain card goes to the discard pile, nothing destroyed")

	# Retain: stays in hand at the end of the turn, a plain card does not.
	e = _enc(DECK5 + DECK5, false)
	c = _give_enh(e, "example1", "anchored")
	var other := _give(e, "example1")
	e.pass_turn()
	_check(e.player.hand.has(c), "Anchored: retained at the end of the turn")
	_check(not e.player.hand.has(other), "Anchored: plain card is not retained")
	_check(c.is_retained() and not c.retain, "Anchored: retained by the enhancement, not the flag")

	# Utility: instant, so playing it doesn't end the turn.
	e = _enc(DECK5 + DECK5, false)
	c = _give_enh(e, "example1", "hasty")
	var round_before := e.round_num
	e.play_card(c)
	_check(c.is_instant() and e.is_player_turn() and e.round_num == round_before, "Hasty: playing it is a free action")

	# Market: playing it adds a plain copy to the deck.
	e = _enc(DECK5 + DECK5)
	c = _give_enh(e, "example1", "franchise")
	var total := _all_count(e, "example1")
	e.play_card(c)
	var after := _all_count(e, "example1")
	_check(after == total + 1, "Franchise: a copy is added to the deck (%d -> %d)" % [total, after])
	var enhanced := 0
	for zone in [e.player.hand, e.player.draw_pile, e.player.discard]:
		for k in zone:
			if not k.enhancements.is_empty():
				enhanced += 1
	_check(enhanced == 1, "Franchise: only the original is enhanced, the copy is plain (no snowball)")

	# Curse Synergy: counts as a curse.
	e = _enc(DECK5 + DECK5)
	c = _give_enh(e, "example1", "tainted")
	_check(c.is_curse() and not c.data.curse, "Tainted: counts as a curse")
	e.player.items.append(ItemInstance.new(_item("cursed_luck")))
	before = e.player.coins
	e.player.hand.erase(c)
	e.player.discard.append(c)
	e.draw_specific(e.player, c)
	_check(e.player.coins > before, "Tainted: drawing it triggers 'when you draw a curse'")
	_check(not _give(e, "example1").is_curse(), "plain card is not a curse")

	# Shop: 1 enhancement slot per themed encounter, only from its sets (+ Utility, Coins).
	for file in THEMES:
		var data: EncounterData = load(ENC_DIR % file)
		var allowed: Array = THEMES[file].duplicate()
		allowed.append(CardSets.Id.UTILITY)
		allowed.append(CardSets.Id.COINS)
		var pool := data.get_enhancement_pool()
		var ok := pool.size() == 4
		for en in pool:
			ok = ok and allowed.has(en.card_set)
		_check(ok, "%s: sells the enhancements of its 4 sets" % file)
		_check(data.enhancement_slots == 1, "%s: 1 enhancement slot" % file)
		e = _enc(DECK5, true, false, ENC_DIR % file)
		_check(e.shop.enhancements.size() == 1 and e.shop.enhancements[0] != null, "%s: enhancement slot is filled" % file)
		var seen := {}
		for i in 40:
			e.shop.restock()
			seen[e.shop.enhancements[0].id] = true
		_check(seen.size() == 4, "%s: the slot rerolls through all 4 enhancements (saw %d)" % [file, seen.size()])

	# Buying: pay, pick a card in hand, it is attached.
	e = _enc(DECK5, true, false, ENC_DIR % "toll_booth")
	e.shop.enhancements[0] = _enh("gilded")
	c = e.player.hand[0]
	var coins := e.player.coins
	_check(e.can_buy_enhancement(0, c), "can buy an enhancement with a card in hand")
	_check(e.buy_enhancement(0, c), "buy_enhancement succeeds")
	_check(c.enhancements.size() == 1 and e.player.coins == coins - 3, "bought: attached, 3 coins paid")
	_check(e.shop.enhancements[0] == null, "bought: slot is empty until the next round")


# ---------------------------------------------------------------- deck cycle

## Draw 5 from the top, buys go to the bottom, played + unplayed cards go to
## the discard pile, and at the end of the turn the shuffled discard pile is
## put under the deck. The deck is never reshuffled mid-turn.
func _deck_cycle_rules() -> void:
	var ids := []
	for i in 12:
		ids.append("example1")
	var e := _enc(ids)
	var p := e.player
	_check(p.hand.size() == 5 and p.draw_pile.size() == 7, "Deck cycle: opening hand is 5 from the deck")
	var top5: Array = p.draw_pile.slice(p.draw_pile.size() - 5)

	# Buy: the card goes to the bottom of the deck (nothing is shuffled).
	var before := p.draw_pile.duplicate()
	var bought := false
	for slot in e.shop.cards.size():
		if e.can_buy_card(slot):
			bought = e.buy_card(slot)
			break
	_check(bought, "Deck cycle: bought a card")
	_check(p.draw_pile.size() == before.size() + 1 and not before.has(p.draw_pile[0]), "Deck cycle: bought card is at the bottom of the deck")
	_check(p.draw_pile.slice(1) == before, "Deck cycle: buying doesn't shuffle the deck")
	var bought_card: CardInstance = p.draw_pile[0]

	# Play one card, leave the rest unplayed; pass the turn.
	var played: CardInstance = p.hand[0]
	var old_hand := p.hand.duplicate()
	e.play_card(played)
	_check(not p.hand.has(played) and p.discard.has(played), "Deck cycle: played card goes to the discard pile")
	_check(e.round_num == 1, "Deck cycle: still the same turn after one action (round %d)" % e.round_num)
	# (the played card may itself have drawn cards from the top)
	var top5_now: Array = p.draw_pile.slice(p.draw_pile.size() - 5)
	var n_under := p.hand.size() + p.discard.size()
	var deck_before := p.draw_pile.size()
	e.pass_turn()
	_check(p.discard.is_empty(), "Deck cycle: discard pile is emptied at the end of the turn")
	var all_under := true
	for c in old_hand:
		if not p.draw_pile.has(c):
			all_under = false
	_check(all_under, "Deck cycle: played and unplayed cards are back in the deck")
	_check(p.draw_pile.size() == deck_before + n_under - 5 and p.hand.size() == 5, "Deck cycle: next hand is 5 from the top")
	var same := true
	for c in top5_now:
		if not p.hand.has(c):
			same = false
	_check(same, "Deck cycle: next hand is the old top 5 (the discards went under it)")
	_check(p.draw_pile.find(bought_card) == n_under, "Deck cycle: bought card sits right above the shuffled discards")
	_consistent(e, "Deck cycle")

	# Deck smaller than 5: draw what's there, and no mid-turn reshuffle.
	e = _enc(["example1", "example1", "example1"])
	p = e.player
	_check(p.hand.size() == 3 and p.draw_pile.is_empty(), "Deck cycle: small deck draws what is there")
	p.discard.append(CardInstance.new(_card("example1")))
	e.draw_cards(p, 2)
	_check(p.hand.size() == 3 and p.discard.size() == 1, "Deck cycle: empty deck is not reshuffled mid-turn")

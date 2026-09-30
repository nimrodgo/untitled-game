extends SceneTree
## Regenerates the current TEST content under res://content/test/ from
## Nimrod's card list (and design/ideas.md). Edit the resulting .tres files in
## the inspector, or change this script and re-run:
##   godot --headless --path . --script res://tools/build_test_content.gd
##
## Names and costs of the ideas.md content are PLACEHOLDERS (Claude's guesses);
## curses C1..C4 and P1 have DUMMY names (Dead Weight, Barnacle, Driftwood,
## Leaky Purse, Snowball); ids match the names (dead_weight, barnacle, driftwood, leaky_purse, snowball).

const DIR := "res://content/test/"

const HAND := GameRules.PILE_HAND
const DECK := GameRules.PILE_DRAW
const DISC := GameRules.PILE_DISCARD
const SELF := GameRules.Target.SELF


func _init() -> void:
	for sub in ["cards", "curses", "items", "trinkets", "enemies", "encounters", "loadouts"]:
		DirAccess.make_dir_recursive_absolute(DIR + sub)

	# --- Nimrod's original cards (text exactly as designed) ----------------
	var example1 := _card("example1", "This is a card", 1, false,
		[_draw(2)], "Draw 2 🂠",
		[_draw(1)], "Draw 1 🂠")
	var example2 := _card("example2", "This is another card", 0, true,
		[_gain(1)], "⚡Gain 1 🪙",
		[_gain(1)], "Gain 1 🪙")
	var per_draw := GainCoinsPerStatEffect.new()
	per_draw.stat = &"cards_drawn_this_turn"
	per_draw.per = 1
	var drawful := _card("drawful", "Draw Synergy", 3, false,
		[per_draw], "Gain 1 🪙 for every card drawn this turn ([i]{cards_drawn_this_turn}[/i])",
		[_draw(1)], "Draw 1 🂠")

	# --- Curses (ideas.md) ---------------------------------------------------
	var dead_weight := _curse("dead_weight", "Dead Weight", [], "", false)
	var barnacle := _curse("barnacle", "Barnacle", [], "Permanent", true)
	var driftwood := _curse("driftwood", "Driftwood", [_trash_self(false)], "Play: remove 🗑 this", false)
	driftwood.playable = true
	_save(driftwood, "curses/driftwood.tres")
	var leaky_purse := _curse("leaky_purse", "Leaky Purse", [], "End of turn in hand: lose 2 🪙", false)
	var lose2 := LoseCoinsEffect.new(); lose2.target = SELF; lose2.amount = 2
	leaky_purse.on_turn_end_in_hand.assign([lose2])
	_save(leaky_purse, "curses/leaky_purse.tres")

	# --- Cards from ideas.md (placeholder names/costs) -----------------------
	var ideas: Array[CardData] = []
	var mv := MoveCardsEffect.new()
	mv.from_piles = DISC; mv.to_zone = GameRules.Zone.HAND; mv.curses_only = true
	ideas.append(_card("curse_recall", "Curse Recall", 1, false, [mv],
		"Return all curses from the discard pile to your hand"))

	var impulse := BuyCardEffect.new(); impulse.play_then_destroy = true
	ideas.append(_card("impulse_buy", "Impulse Buy", 2, false, [impulse],
		"Buy a card and play it immediately. Then destroy 🔥 it"))

	ideas.append(_card("sift", "Sift", 1, false, [_draw(2), _discard(2)],
		"Draw 2 🂠. Discard 2 ⤵"))

	var refresh_all := RefreshTrinketsEffect.new(); refresh_all.all = true
	ideas.append(_card("spark", "Spark", 1, true, [_trash_self(true), refresh_all],
		"⚡🔥 this ➡ Refresh ↺ all trinkets"))

	ideas.append(_card("patience", "Patience", 1, true,
		[_choose([_opt([_gain(2)], "Gain 2 🪙"), _opt([PassEffect.new(), _gain(3)], "Pass ➡ Gain 3 🪙")])],
		"⚡Gain 2 🪙 OR Pass ➡ Gain 3 🪙"))

	ideas.append(_card("purge", "Purge", 2, false,
		[_choose([_opt([_trash(true, 1)], "Destroy 1 🔥"), _opt([_trash(false, 2)], "Remove 2 🗑")])],
		"Destroy 1 🔥 OR Remove 2 🗑"))

	ideas.append(_card("cycle", "Cycle", 1, false, [_discard(1, true), _draw(2)],
		"Discard 1 ⤵ ➡ Draw 2 🂠"))

	ideas.append(_card("rush_order", "Rush Order", 1, true, [NextBuyToHandEffect.new()],
		"⚡The next card you buy is drawn immediately"))

	ideas.append(_card("burnout", "Burnout", 2, true, [_trash_self(true), _draw(5)],
		"⚡🔥 this ➡ Draw 5 🂠"))

	ideas.append(_card("clearance", "Clearance", 2, true, [DestroyShopCardEffect.new(), _gain(2)],
		"⚡Destroy 🔥 a card in the shop and restock it. Gain 2 🪙"))

	var refresh1 := RefreshTrinketsEffect.new()
	ideas.append(_card("tinker", "Tinker", 1, false, [refresh1, _draw(1)],
		"Refresh ↺ a trinket. Draw 1 🂠"))

	var bottom := _draw(1); bottom.source = DrawCardsEffect.Source.BOTTOM
	ideas.append(_card("undertow", "Undertow", 1, false, [bottom],
		"Draw 1 🂠 from the bottom of your deck"))

	var buy_removed := BuyCardEffect.new(); buy_removed.source = BuyCardEffect.Source.REMOVED
	ideas.append(_card("salvage", "Salvage", 1, false, [buy_removed],
		"Buy a card you removed 🗑 this encounter"))

	var buy_destroyed := BuyCardEffect.new(); buy_destroyed.source = BuyCardEffect.Source.DESTROYED
	ideas.append(_card("phoenix", "Phoenix", 1, false, [buy_destroyed],
		"Buy a card you destroyed 🔥 this encounter"))

	ideas.append(_card("cursed_cache", "Cursed Cache", 0, false, [_add(driftwood), _draw(2)],
		"Shuffle Driftwood into your deck. Draw 2 🂠"))

	var tf := TransformCardsEffect.new(); tf.into = driftwood
	ideas.append(_card("hex", "Hex", 1, false, [tf],
		"Transform any cards in your hand to Driftwood"))

	ideas.append(_card("borrowed_power", "Borrowed Power", 2, false, [ActivateShopTrinketEffect.new()],
		"Activate the level 3 effect of a trinket in the shop"))

	var ntd := NextTurnDrawEffect.new(); ntd.amount = 3
	ideas.append(_card("rest", "Rest", 0, false, [PassEffect.new(), ntd],
		"Pass ➡ Draw 3 🂠 at the start of your next turn"))

	var sweep := MoveCardsEffect.new()
	sweep.from_piles = DECK; sweep.to_zone = GameRules.Zone.DRAW_BOTTOM; sweep.curses_only = true
	ideas.append(_card("sweep", "Sweep Under", 1, false, [sweep, _draw(1)],
		"Move all curses in your deck to the bottom. Draw 1 🂠"))

	ideas.append(_card("tidy_up", "Tidy Up", 1, false,
		[_gain(1), _if(ConditionalEffect.Condition.DISCARD_EMPTY, [_draw(1)])],
		"Gain 1 🪙. If your discard pile is empty, draw 1 🂠"))

	var sample := BuyCardEffect.new(); sample.free = true; sample.zone = GameRules.Zone.DRAW_TOP
	ideas.append(_card("free_sample", "Free Sample", 3, false, [sample],
		"Buy a card for free and place it on top of the draw pile"))

	var prune_rm := _trash(false, 1); prune_rm.piles = HAND
	ideas.append(_card("prune", "Prune", 1, false, [_draw(2), prune_rm],
		"Draw 2 🂠. Remove 1 🗑 in hand"))

	ideas.append(_card("autopilot", "Autopilot", 2, false, [PlayTopCardsEffect.new()],
		"Play the top 2 cards in your deck"))

	var pay2 := PayCoinsEffect.new(); pay2.amount = 2
	ideas.append(_card("invest", "Invest", 1, false, [pay2, _draw(3)],
		"Pay 2 🪙 ➡ Draw 3 🂠"))

	var liq := TrashCardsEffect.new()
	liq.destroy = false; liq.what = TrashCardsEffect.What.ALL_OTHER_HAND; liq.coins_per_card = 3
	ideas.append(_card("liquidate", "Liquidate", 2, false, [liq],
		"Remove 🗑 all other cards in your hand. Gain 3 🪙 for each"))

	ideas.append(_card("echo", "Echo", 2, false, [ReplayEffect.new()],
		"The next card you play this turn is played an additional time"))

	ideas.append(_card("cursed_coin", "Cursed Coin", 0, false, [_add(barnacle), _gain(2)],
		"Gain Barnacle and 2 🪙"))

	var ember := _card("ember", "Ember", 1, false, [_gain(2)],
		"Gain 2 🪙. When this is destroyed 🔥, draw 2 🂠")
	ember.on_destroy.assign([_draw(2)])
	_save(ember, "cards/ember.tres")
	ideas.append(ember)

	var ontop := MoveCardsEffect.new()
	ontop.from_piles = HAND; ontop.to_zone = GameRules.Zone.DRAW_TOP; ontop.amount = 1
	ideas.append(_card("scheme", "Scheme", 1, false, [_draw(3), ontop],
		"Draw 3 🂠. Put a card in your hand on top of the draw pile"))

	ideas.append(_card("binge", "Binge", 1, false, [_draw(3), DrawLockEffect.new()],
		"Draw 3 🂠. You can't draw additional cards this turn"))

	var mull := DiscardCardsEffect.new(); mull.all_hand = true; mull.draw_that_many = true
	ideas.append(_card("mulligan", "Mulligan", 1, false, [mull],
		"Discard your hand ⤵. Draw that many 🂠"))

	var spring := _card("spring", "Spring", 1, false, [_draw(1)],
		"Draw 1 🂠. When this card is discarded ⤵, draw 2 🂠")
	spring.on_discard.assign([_draw(2)])
	_save(spring, "cards/spring.tres")
	ideas.append(spring)

	ideas.append(_card("study", "Study", 1, false, [_draw(3), _discard(1)],
		"Draw 3 🂠. Discard 1 ⤵"))

	var necro := PlayCopyEffect.new(); necro.source = PlayCopyEffect.Source.DESTROYED
	ideas.append(_card("necromancy", "Necromancy", 2, false, [necro],
		"Play the effect of a card that was destroyed 🔥 this encounter"))

	var dbl := GainCoinsPerStatEffect.new(); dbl.stat = &"coins"; dbl.per = 1
	ideas.append(_card("all_in", "All In", 3, false, [_if(ConditionalEffect.Condition.DECK_EMPTY, [dbl])],
		"Double your 🪙 if your deck is empty"))

	ideas.append(_card("mimic", "Mimic", 2, false, [PlayCopyEffect.new()],
		"Play the effect of the last card you played this turn"))

	ideas.append(_card("meditate", "Meditate", 0, false,
		[PassEffect.new(), _if(ConditionalEffect.Condition.NO_OTHER_CARD_PLAYED, [ExtraRoundEffect.new(), _trash_self(true)])],
		"Pass. If you didn't play any card this turn, take an extra turn and destroy 🔥 this"))

	ideas.append(_card("peek", "Peek", 0, false, [DiscardFromDeckEffect.new(), _draw(1)],
		"You may discard ⤵ the top card of your deck. Draw 1 🂠"))

	var burn_deck := TrashCardsEffect.new(); burn_deck.what = TrashCardsEffect.What.DRAW_PILE
	ideas.append(_card("scorched_earth", "Scorched Earth", 1, false, [_trash_self(true), burn_deck, _gain(5)],
		"Destroy 🔥 this card and your deck. Gain 5 🪙"))

	ideas.append(_card("hold", "Hold", 1, false, [_gain(1), RetainCardsEffect.new()],
		"Gain 1 🪙. Choose 1 card to retain this turn"))

	var dig_draw := _draw(1); dig_draw.source = DrawCardsEffect.Source.DISCARD_CHOOSE
	ideas.append(_card("dig", "Dig", 1, false, [dig_draw, _trash_self(false)],
		"Draw 1 🂠 from the discard pile and remove 🗑 this"))

	ideas.append(_card("snowball", "Snowball", 1, false, [GainCoinsScalingEffect.new()],
		"Gain 2 🪙 and increase gain from all Snowballs by 2 this encounter"))

	ideas.append(_card("risky_draw", "Risky Draw", 0, false, [_draw(3), _add(leaky_purse)],
		"Draw 3 🂠. Shuffle Leaky Purse into your deck"))

	# Listed under items in ideas.md, but meant to be a card.
	var pawn := _trash(true, 1); pawn.piles = HAND; pawn.gain_cost_as_coins = true
	ideas.append(_card("pawn", "Pawn", 1, false, [pawn],
		"Destroy 1 🔥 in hand. Gain 🪙 equal to its cost"))

	# --- Items -----------------------------------------------------------------
	var T := GameRules.Trigger
	var original_items := [
		_item("rebate", "Rebate", 3, T.CARD_BOUGHT, [_gain(1)], 0, 0, "Gain 1 🪙 when you buy a card"),
	]
	var dest := SetBuyDestinationEffect.new()
	dest.destination = GameRules.Zone.HAND
	original_items.append(_item("express_delivery", "Express Delivery", 2, T.BEFORE_CARD_BUY, [dest], 1, 0,
		"The first card you buy each encounter goes to your hand"))

	var burn_played := _trash_self(true)
	var retain_opt := RetainCardsEffect.new(); retain_opt.optional = true
	var extra_play := ReplayEffect.new(); extra_play.mode = ReplayEffect.Mode.THIS_CARD
	var idea_items := [
		_item("furnace", "Furnace", 2, T.CARD_PLAYED, [burn_played], 0, 1,
			"The first card you play each turn is destroyed 🔥"),
		_item("scrap_dealer", "Scrap Dealer", 4, T.CARD_REMOVED, [_gain(2)], 0, 0,
			"When you remove 🗑 a card, gain 2 🪙"),
		_item("incinerator", "Incinerator", 5, T.CARD_DESTROYED, [_gain(3)], 0, 0,
			"When you destroy 🔥 a card, gain 3 🪙"),
		_item("cursed_luck", "Cursed Luck", 3, T.CURSE_DRAWN, [_gain(2)], 0, 0,
			"When you draw a curse, gain 2 🪙"),
		_item("curse_ward", "Curse Ward", 3, T.CURSE_DRAWN, [_draw(1)], 0, 0,
			"When you draw a curse, draw 1 🂠"),
		_item("recycler", "Recycler", 4, T.CARD_TRASHED_FROM_HAND, [_draw(1)], 0, 0,
			"When you remove 🗑 or destroy 🔥 a card in your hand, draw 1 🂠"),
		_item("pocket", "Pocket", 4, T.ROUND_END, [retain_opt], 0, 0,
			"You may retain 1 card each turn"),
		_item("grindstone", "Grindstone", 5, T.CARD_DISCARDED, [_gain(2)], 0, 0,
			"When you discard ⤵, gain 2 🪙"),
		_item("second_look", "Second Look", 3, T.CARD_DRAWN, [OfferRedrawEffect.new()], 0, 1,
			"When you draw a card during your turn, you may discard ⤵ it to draw another. Then this is disabled for the turn"),
		_item("big_hands", "Big Hands", 5, T.HAND_DRAWN, [_draw(1)], 0, 0,
			"Draw an additional 🂠 at the start of the turn"),
		_item("echo_chamber", "Echo Chamber", 6, T.CARD_PLAYED, [extra_play], 0, 1,
			"The first card you play each turn is played an extra time"),
	]

	# --- Trinkets ------------------------------------------------------------------
	var coin_trinket := _trinket("coin_trinket", "Coin Trinket", 4, [[[_gain(1)], "⚡Gain 1 🪙", 0]])
	var pay1 := PayCoinsEffect.new(); pay1.amount = 1
	var t_forge := _trinket("forge", "Forge", 3, [
		[[pay1, _trash(true, 1)], "⚡Pay 1 🪙 ➡ Destroy 1 🔥", 0],
		[[_trash(true, 1)], "⚡Destroy 1 🔥", 3],
		[[_gain(1), _trash(true, 1)], "⚡Gain 1 🪙. Destroy 1 🔥", 3]])
	var t_idol := _trinket("cursed_idol", "Cursed Idol", 4, [
		[[_add(barnacle), _gain(2)], "⚡Gain Barnacle and 2 🪙", 0],
		[[_add(barnacle), _gain(4)], "⚡Gain Barnacle and 4 🪙", 4],
		[[_add(barnacle), _gain(6)], "⚡Gain Barnacle and 6 🪙", 5]])
	var t_sieve := _trinket("sieve", "Sieve", 4, [
		[[_draw(1), _discard(1)], "⚡Draw 1 🂠. Discard 1 ⤵", 0],
		[[_draw(2), _discard(1)], "⚡Draw 2 🂠. Discard 1 ⤵", 3],
		[[_draw(3), _discard(1)], "⚡Draw 3 🂠. Discard 1 ⤵", 4]])
	var t_urn := _trinket("ash_urn", "Ash Urn", 3, [
		[[_add(barnacle), _trash(true, 1)], "⚡Shuffle 1 Barnacle into your deck. Destroy 1 🔥", 0],
		[[_add(barnacle), _trash(true, 2)], "⚡Shuffle 1 Barnacle into your deck. Destroy 2 🔥", 3],
		[[_add(barnacle, 2), _trash(true, 3)], "⚡Shuffle 2 Barnacles into your deck. Destroy 3 🔥", 4]])
	var t_pan := _trinket("dust_pan", "Dust Pan", 3, [
		[[_add(dead_weight), _trash(false, 2)], "⚡Shuffle 1 Dead Weight into your deck. Remove 2 🗑", 0],
		[[_add(dead_weight), _trash(false, 3)], "⚡Shuffle 1 Dead Weight into your deck. Remove 3 🗑", 3],
		[[_add(dead_weight, 2), _trash(false, 4)], "⚡Shuffle 2 Dead Weights into your deck. Remove 4 🗑", 4]])
	var t_glass := _trinket("spyglass", "Spyglass", 3, [
		[[_peek(2)], "⚡Look at the top 2 cards of your deck. Discard ⤵ any of them", 0],
		[[_peek(3)], "⚡Look at the top 3 cards of your deck. Discard ⤵ any of them", 3],
		[[_peek(4)], "⚡Look at the top 4 cards of your deck. Discard ⤵ any of them", 3]])

	# --- Enemy (scripted intents; no cards/items) ---------------------------
	var snatch := SnatchShopCardEffect.new()
	snatch.mode = SnatchShopCardEffect.Mode.PRICIEST
	var enemy := EnemyData.new()
	enemy.display_name = "TEST Moray"
	enemy.intents.assign([
		_intent("Pinch", EnemyIntent.Kind.STEAL, [_steal(1)]),
		_intent("Toll", EnemyIntent.Kind.ATTACK, [_lose(1)]),
		_intent("Snatch", EnemyIntent.Kind.SHOP, [snatch]),
	])
	_save(enemy, "enemies/test_enemy.tres")

	# --- Encounter + starting loadout -----------------------------------------
	var enc := EncounterData.new()
	enc.display_name = "TEST Encounter"
	enc.rounds = 3
	enc.coin_target = 10
	enc.gold_reward = 10
	enc.enemy = enemy
	var pool: Array[CardData] = [example1, example2, drawful]
	pool.append_array(ideas)
	enc.card_pool.assign(pool)
	var items: Array = original_items + idea_items
	enc.item_pool.assign(items)
	enc.trinket_pool.assign([coin_trinket, t_forge, t_idol, t_sieve, t_urn, t_pan, t_glass])
	enc.card_slots = 3
	enc.enhancement_slots = 0
	_save(enc, "encounters/test_encounter.tres")

	var lo := LoadoutData.new()
	lo.starting_coins = 3
	lo.starting_deck.assign([example2, example2, example2, example2, example2, example1, example1, example1])
	_save(lo, "loadouts/test_loadout.tres")

	print("Test content written to ", DIR, " (%d idea cards, %d items, 7 trinkets, 4 curses)" % [ideas.size(), items.size()])
	quit()


func _card(id: String, n: String, cost: int, instant: bool, play: Array, play_text: String,
		buy: Array = [], buy_text: String = "") -> CardData:
	var c := CardData.new()
	c.id = StringName(id); c.display_name = n; c.cost = cost; c.instant = instant
	c.on_play.assign(play); c.on_buy.assign(buy)
	c.on_play_text = play_text; c.on_buy_text = buy_text
	_save(c, "cards/%s.tres" % id)
	return c


func _curse(id: String, n: String, play: Array, text: String, permanent: bool) -> CardData:
	var c := CardData.new()
	c.id = StringName(id); c.display_name = n; c.cost = 0
	c.curse = true; c.playable = false; c.permanent = permanent
	c.on_play.assign(play)
	c.on_play_text = text
	_save(c, "curses/%s.tres" % id)
	return c


func _item(id: String, n: String, cost: int, trig: GameRules.Trigger, fx: Array, per_enc: int, per_round: int,
		text: String) -> ItemData:
	var it := ItemData.new()
	it.id = StringName(id); it.display_name = n; it.cost = cost; it.trigger = trig
	it.effects.assign(fx); it.limit_per_encounter = per_enc; it.limit_per_round = per_round
	it.description = text
	_save(it, "items/%s.tres" % id)
	return it


## levels: [[effects, text, upgrade_cost], ...]
func _trinket(id: String, n: String, cost: int, levels: Array) -> TrinketData:
	var t := TrinketData.new()
	t.id = StringName(id); t.display_name = n; t.cost = cost
	var lv: Array[TrinketLevel] = []
	for l in levels:
		var tl := TrinketLevel.new()
		tl.effects.assign(l[0]); tl.text = l[1]; tl.upgrade_cost = l[2]
		lv.append(tl)
	t.levels.assign(lv)
	_save(t, "trinkets/%s.tres" % id)
	return t


func _intent(n: String, kind: EnemyIntent.Kind, fx: Array) -> EnemyIntent:
	var i := EnemyIntent.new()
	i.display_name = n
	i.kind = kind
	i.effects.assign(fx)
	return i


func _gain(n: int) -> Effect:
	var e := GainCoinsEffect.new(); e.amount = n; return e

## Enemy intents: the player loses coins.
func _lose(n: int) -> Effect:
	var e := LoseCoinsEffect.new(); e.amount = n; e.target = GameRules.Target.OPPONENT; return e

func _steal(n: int) -> Effect:
	var e := StealCoinsEffect.new(); e.amount = n; return e

func _draw(n: int) -> DrawCardsEffect:
	var e := DrawCardsEffect.new(); e.amount = n; return e

func _discard(n: int, cost := false) -> DiscardCardsEffect:
	var e := DiscardCardsEffect.new(); e.amount = n; e.as_cost = cost; return e

func _trash(destroy: bool, n: int) -> TrashCardsEffect:
	var e := TrashCardsEffect.new(); e.destroy = destroy; e.amount = n; return e

func _trash_self(destroy: bool) -> TrashCardsEffect:
	var e := TrashCardsEffect.new(); e.destroy = destroy; e.what = TrashCardsEffect.What.SELF; e.as_cost = true; return e

func _add(card: CardData, n := 1) -> AddCardEffect:
	var e := AddCardEffect.new(); e.card = card; e.amount = n; e.target = SELF; return e

func _peek(n: int) -> DiscardFromDeckEffect:
	var e := DiscardFromDeckEffect.new(); e.look = n; return e

func _opt(fx: Array, label: String) -> EffectOption:
	var o := EffectOption.new(); o.effects.assign(fx); o.label = label; return o

func _choose(opts: Array) -> ChooseOneEffect:
	var e := ChooseOneEffect.new(); e.options.assign(opts); return e

func _if(cond: ConditionalEffect.Condition, fx: Array) -> ConditionalEffect:
	var e := ConditionalEffect.new(); e.condition = cond; e.effects.assign(fx); return e


func _save(res: Resource, rel: String) -> void:
	var path := DIR + rel
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s: %s" % [path, err])
	res.take_over_path(path)

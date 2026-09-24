extends SceneTree
## Regenerates the current TEST content under res://content/test/ from
## Nimrod's card list. Edit the resulting .tres files in the inspector, or
## change this script and re-run:
##   godot --headless --path . --script res://tools/build_test_content.gd

const DIR := "res://content/test/"


func _init() -> void:
	for sub in ["cards", "items", "trinkets", "enemies", "encounters", "loadouts"]:
		DirAccess.make_dir_recursive_absolute(DIR + sub)

	# --- Cards (text exactly as designed) ---------------------------------
	var example1 := _card("example1", "This is a card", 1, false,
		[_draw(2)], "Draw 2 🂠",
		[_draw(1)], "Draw 1 🂠")
	var example2 := _card("example2", "This is another card", 0, true,
		[_gain(1)], "🗲Gain 1 🪙",
		[_gain(1)], "Gain 1 🪙")
	var per_draw := GainCoinsPerStatEffect.new()
	per_draw.stat = &"cards_drawn_this_turn"
	per_draw.per = 1
	var drawful := _card("drawful", "Draw Synergy", 3, false,
		[per_draw], "Gain 1 🪙 for every card drawn this turn ([i]{cards_drawn_this_turn}[/i])",
		[_draw(1)], "Draw 1 🂠")

	# --- Items (from the concept) ------------------------------------------
	var rebate := _item("rebate", "Rebate", 3, GameRules.Trigger.CARD_BOUGHT, [_gain(1)], 0,
		"Gain 1 🪙 when you buy a card")
	var dest := SetBuyDestinationEffect.new()
	dest.destination = GameRules.Zone.HAND
	var express := _item("express_delivery", "Express Delivery", 2, GameRules.Trigger.BEFORE_CARD_BUY, [dest], 1,
		"The first card you buy each encounter goes to your hand")

	# --- Trinket -------------------------------------------------------------
	var trinket := TrinketData.new()
	trinket.id = &"coin_trinket"
	trinket.display_name = "Coin Trinket"
	trinket.cost = 4
	var lvl := TrinketLevel.new()
	lvl.effects.assign([_gain(1)])
	lvl.text = "🗲Gain 1 🪙"
	trinket.levels.assign([lvl])
	_save(trinket, "trinkets/coin_trinket.tres")

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
	enc.card_pool.assign([example1, example2, drawful])
	enc.item_pool.assign([rebate, express])
	enc.trinket_pool.assign([trinket])
	enc.card_slots = 3
	enc.enhancement_slots = 0
	_save(enc, "encounters/test_encounter.tres")

	var lo := LoadoutData.new()
	lo.starting_coins = 3
	lo.starting_deck.assign([example2, example2, example2, example2, example2, example1, example1, example1])
	_save(lo, "loadouts/test_loadout.tres")

	print("Test content written to ", DIR)
	quit()


func _card(id: String, n: String, cost: int, instant: bool, play: Array, play_text: String,
		buy: Array, buy_text: String) -> CardData:
	var c := CardData.new()
	c.id = StringName(id); c.display_name = n; c.cost = cost; c.instant = instant
	c.on_play.assign(play); c.on_buy.assign(buy)
	c.on_play_text = play_text; c.on_buy_text = buy_text
	_save(c, "cards/%s.tres" % id)
	return c


func _item(id: String, n: String, cost: int, trig: GameRules.Trigger, fx: Array, per_enc: int, text: String) -> ItemData:
	var it := ItemData.new()
	it.id = StringName(id); it.display_name = n; it.cost = cost; it.trigger = trig
	it.effects.assign(fx); it.limit_per_encounter = per_enc
	it.description = text
	_save(it, "items/%s.tres" % id)
	return it


func _intent(n: String, kind: EnemyIntent.Kind, fx: Array) -> EnemyIntent:
	var i := EnemyIntent.new()
	i.display_name = n
	i.kind = kind
	i.effects.assign(fx)
	return i


func _gain(n: int) -> Effect:
	var e := GainCoinsEffect.new(); e.amount = n; return e

func _lose(n: int) -> Effect:
	var e := LoseCoinsEffect.new(); e.amount = n; return e

func _steal(n: int) -> Effect:
	var e := StealCoinsEffect.new(); e.amount = n; return e

func _draw(n: int) -> Effect:
	var e := DrawCardsEffect.new(); e.amount = n; return e


func _save(res: Resource, rel: String) -> void:
	var path := DIR + rel
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s: %s" % [path, err])
	res.take_over_path(path)

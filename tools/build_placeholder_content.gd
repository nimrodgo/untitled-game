extends SceneTree
## Regenerates the TEST placeholder content under res://content/_placeholder/.
## These exist only to exercise every system; replace them with real designs.
## Run:  godot --headless --script res://tools/build_placeholder_content.gd

const DIR := "res://content/_placeholder/"


func _init() -> void:
	for sub in ["cards", "items", "trinkets", "enhancements", "enemies", "encounters", "loadouts"]:
		DirAccess.make_dir_recursive_absolute(DIR + sub)

	var coin := _card("test_coin", "TEST Coin", 0, false, [_gain(1)], [])
	var draw := _card("test_draw", "TEST Draw", 2, false, [_draw(2)], [])
	var steal := _card("test_steal", "TEST Steal", 3, false, [_steal(1)], [])
	var instant := _card("test_instant", "TEST Instant", 3, true, [_gain(1)], [])
	var on_buy := _card("test_on_buy", "TEST On-Buy", 3, false, [_gain(1)], [_gain(2)])
	var drain := _card("test_drain", "TEST Drain", 3, false, [_lose(2)], [])
	var discard := _card("test_discard", "TEST Discard", 2, false, [_discard(1)], [])
	var extra := _card("test_extra", "TEST Extra Action", 2, false, [_gain(1), ExtraActionEffect.new()], [])

	var rebate := _item("test_item_rebate", "TEST Rebate", 3, GameRules.Trigger.CARD_BOUGHT, [_gain(1)], 0, 0)
	var dest := SetBuyDestinationEffect.new()
	dest.destination = GameRules.Zone.HAND
	var express := _item("test_item_express", "TEST Express Delivery", 2, GameRules.Trigger.BEFORE_CARD_BUY, [dest], 1, 0)

	var trinket := TrinketData.new()
	trinket.id = &"test_trinket"
	trinket.display_name = "TEST Trinket"
	trinket.cost = 4
	trinket.levels = [_level(0, [_gain(1)]), _level(3, [_gain(2)]), _level(5, [_gain(2), _draw(1)])]
	_save(trinket, "trinkets/test_trinket.tres")

	var enh_instant := EnhancementData.new()
	enh_instant.id = &"test_enh_instant"; enh_instant.display_name = "TEST Make Instant"; enh_instant.cost = 3
	enh_instant.make_instant = true
	_save(enh_instant, "enhancements/test_enh_instant.tres")
	var enh_coin := EnhancementData.new()
	enh_coin.id = &"test_enh_coin"; enh_coin.display_name = "TEST +1 Coin"; enh_coin.cost = 2
	enh_coin.extra_on_play = [_gain(1)]
	_save(enh_coin, "enhancements/test_enh_coin.tres")

	var junk := _card("test_junk", "TEST Junk", 0, false, [], [])
	var tariff := _item("test_item_tariff", "TEST Tariff", 0, GameRules.Trigger.OPPONENT_CARD_BOUGHT, [_lose(1)], 0, 1)

	var snatch := SnatchShopCardEffect.new()
	snatch.mode = SnatchShopCardEffect.Mode.PRICIEST
	var add_junk := AddCardEffect.new()
	add_junk.card = junk
	var enemy := EnemyData.new()
	enemy.display_name = "TEST Moray"
	enemy.intents = [
		_intent("Pinch", EnemyIntent.Kind.STEAL, [_steal(1)]),
		_intent("Toll", EnemyIntent.Kind.ATTACK, [_lose(1)]),
		_intent("Snatch", EnemyIntent.Kind.SHOP, [snatch]),
		_intent("Brine Curse", EnemyIntent.Kind.CURSE, [add_junk]),
	]
	enemy.items = [tariff]
	_save(enemy, "enemies/test_enemy.tres")

	var enc := EncounterData.new()
	enc.display_name = "TEST Encounter"
	enc.rounds = 3
	enc.coin_target = 6
	enc.gold_reward = 10
	enc.enemy = enemy
	enc.card_pool = [draw, steal, instant, on_buy, drain, discard, extra]
	enc.item_pool = [rebate, express]
	enc.trinket_pool = [trinket]
	enc.enhancement_pool = [enh_instant, enh_coin]
	_save(enc, "encounters/test_encounter.tres")

	var lo := LoadoutData.new()
	lo.starting_coins = 3
	lo.starting_deck = [coin, coin, coin, coin, coin, coin, coin, draw]
	_save(lo, "loadouts/test_loadout.tres")

	print("Placeholder content written to ", DIR)
	quit()


func _card(id: String, n: String, cost: int, instant: bool, play: Array, buy: Array) -> CardData:
	var c := CardData.new()
	c.id = StringName(id); c.display_name = n; c.cost = cost; c.instant = instant
	c.on_play.assign(play); c.on_buy.assign(buy)
	c.flavor_text = "Placeholder card for testing."
	_save(c, "cards/%s.tres" % id)
	return c


func _item(id: String, n: String, cost: int, trig: GameRules.Trigger, fx: Array, per_enc: int, per_round: int) -> ItemData:
	var it := ItemData.new()
	it.id = StringName(id); it.display_name = n; it.cost = cost; it.trigger = trig
	it.effects.assign(fx); it.limit_per_encounter = per_enc; it.limit_per_round = per_round
	_save(it, "items/%s.tres" % id)
	return it


func _intent(n: String, kind: EnemyIntent.Kind, fx: Array) -> EnemyIntent:
	var i := EnemyIntent.new()
	i.display_name = n
	i.kind = kind
	i.effects.assign(fx)
	return i


func _level(cost: int, fx: Array) -> TrinketLevel:
	var l := TrinketLevel.new()
	l.upgrade_cost = cost
	l.effects.assign(fx)
	return l


func _gain(n: int, t := GameRules.Target.SELF) -> Effect:
	var e := GainCoinsEffect.new(); e.amount = n; e.target = t; return e

func _lose(n: int) -> Effect:
	var e := LoseCoinsEffect.new(); e.amount = n; return e

func _steal(n: int) -> Effect:
	var e := StealCoinsEffect.new(); e.amount = n; return e

func _draw(n: int) -> Effect:
	var e := DrawCardsEffect.new(); e.amount = n; return e

func _discard(n: int) -> Effect:
	var e := DiscardRandomEffect.new(); e.amount = n; return e


func _save(res: Resource, rel: String) -> void:
	var path := DIR + rel
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s: %s" % [path, err])
	res.take_over_path(path)

extends SceneTree
## Builds the 5 themed encounters (docs: "Encounters v1" in the project). Each
## encounter just names its card sets (EncounterData.card_sets); the shop pools
## fill themselves from the existing content (ContentLibrary), so nothing here
## reads or touches your cards. Writes:
##   content/test/enemies/<enemy>.tres        5 enemies
##   content/test/enemy_items/toll.tres       Barracuda's passive
##   content/test/encounters/<encounter>.tres 5 encounters
## Run:  godot --headless --path . --script res://tools/build_encounters.gd
##
## Each encounter sells two themed sets + Utility + Coins (Utility and Coins are
## added automatically). You can also edit `card_sets` in the inspector.
## Names are placeholders. The old TEST Encounter / TEST Moray are left alone
## (tools/test_mechanics.gd uses them).

const DIR := "res://content/test/"
const S := CardSets.Id
const Kind := EnemyIntent.Kind
const OPP := GameRules.Target.OPPONENT

var _curse := {}


func _init() -> void:
	for sub in ["enemies", "enemy_items", "encounters"]:
		DirAccess.make_dir_recursive_absolute(DIR + sub)
	for id in ["dead_weight", "barnacle", "driftwood", "leaky_purse"]:
		_curse[id] = load(DIR + "curses/%s.tres" % id)

	# --- A. Trim + Curse Synergy: the Sea Hag floods your deck with curses ---
	var hag := _enemy("Sea Hag", Color("8e6bbf"), [
		_intent("Hex", Kind.CURSE, "Shuffle Leaky Purse into your deck",
			[_add(_curse["leaky_purse"], GameRules.Zone.DRAW_SHUFFLE)]),
		_intent("Tithe", Kind.ATTACK, "You lose 1 🪙", [_lose(1)]),
		_intent("Foul Brew", Kind.CURSE, "Shuffle a random curse into your deck",
			[_random_curse(["dead_weight", "driftwood", "leaky_purse"])]),
	])
	_encounter("Hag's Hex", "hags_hex", hag, [S.TRIM, S.CURSE_SYNERGY])

	# --- B. Draw + Discard: the Cuttlefish makes you discard and shuts off draws ---
	var squid := _enemy("Cuttlefish", Color("6fa8dc"), [
		_intent("Ink Spray", Kind.ATTACK, "You ⤵ a card at random", [_discard_random(1)]),
		_intent("Pinch", Kind.STEAL, "Steal 1 🪙", [_steal(1)]),
		_intent("Murk", Kind.OTHER, "You can't draw additional cards this turn", [_draw_lock()]),
	])
	_encounter("Ink Cloud", "ink_cloud", squid, [S.DRAW, S.DISCARD])

	# --- C. Market + Draw: the Barracuda snatches cards and taxes every buy ---
	var toll := ItemData.new()
	toll.id = &"toll"; toll.display_name = "Toll"; toll.cost = 0
	toll.trigger = GameRules.Trigger.OPPONENT_CARD_BOUGHT
	toll.effects.assign([_lose(1)])
	toll.limit_per_round = 1
	toll.description = "When you buy a card, you lose 1 🪙 (once per round)"
	_save(toll, "enemy_items/toll.tres")
	var cuda := _enemy("Barracuda", Color("7f8c8d"), [
		_intent("Snatch", Kind.SHOP, "Remove the cheapest market card", [_snatch(SnatchShopCardEffect.Mode.CHEAPEST)]),
		_intent("Pinch", Kind.STEAL, "Steal 1 🪙", [_steal(1)]),
		_intent("Grab", Kind.SHOP, "Remove the priciest market card", [_snatch(SnatchShopCardEffect.Mode.PRICIEST)]),
	])
	cuda.items.assign([toll])
	_encounter("Toll Booth", "toll_booth", cuda, [S.MARKET, S.DRAW])

	# --- D. Curse Synergy + Market: the Loan Shark lends curses and repossesses cards ---
	var shark := _enemy("Loan Shark", Color("c0504d"), [
		_intent("Loan", Kind.CURSE, "Leaky Purse on top of your deck (drawn next)",
			[_add(_curse["leaky_purse"], GameRules.Zone.DRAW_TOP)]),
		_intent("Interest", Kind.ATTACK, "You lose 2 🪙", [_lose(2)]),
		_intent("Repo", Kind.SHOP, "Remove the priciest market card", [_snatch(SnatchShopCardEffect.Mode.PRICIEST)]),
	])
	_encounter("Loan Shark", "loan_shark", shark, [S.CURSE_SYNERGY, S.MARKET])

	# --- E. Discard + Trim: the Hagfish clogs your hand ---
	var hagfish := _enemy("Hagfish", Color("a0a58c"), [
		_intent("Slime", Kind.CURSE, "Add a Dead Weight to your hand",
			[_add(_curse["dead_weight"], GameRules.Zone.HAND)]),
		_intent("Squeeze", Kind.ATTACK, "You ⤵ a card at random", [_discard_random(1)]),
		_intent("Pinch", Kind.STEAL, "Steal 1 🪙", [_steal(1)]),
	])
	_encounter("Clutter", "clutter", hagfish, [S.DISCARD, S.TRIM])

	print("Encounters written to ", DIR, "encounters/")
	quit()


func _encounter(title: String, file: String, enemy: EnemyData, sets: Array) -> void:
	_save(enemy, "enemies/%s.tres" % enemy.display_name.to_lower().replace(" ", "_"))
	var enc := EncounterData.new()
	enc.display_name = title
	enc.rounds = 3
	enc.coin_target = 10
	enc.gold_reward = 10
	enc.enemy = enemy
	enc.card_sets.assign(sets)
	enc.card_slots = 3
	enc.item_slots = 1
	enc.trinket_slots = 1
	enc.enhancement_slots = 1
	_save(enc, "encounters/%s.tres" % file)
	print("%-10s cards %d, items %d, trinkets %d, enhancements %d" % [title, enc.get_card_pool().size(), enc.get_item_pool().size(), enc.get_trinket_pool().size(), enc.get_enhancement_pool().size()])


func _save(res: Resource, rel: String) -> void:
	var path := DIR + rel
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s: %s" % [path, err])
	res.take_over_path(path)


func _enemy(n: String, color: Color, intents: Array) -> EnemyData:
	var e := EnemyData.new()
	e.display_name = n
	e.color = color
	e.intents.assign(intents)
	e.actions_per_round = 3
	return e


func _intent(n: String, kind: EnemyIntent.Kind, text: String, fx: Array) -> EnemyIntent:
	var i := EnemyIntent.new()
	i.display_name = n
	i.kind = kind
	i.description = text
	i.effects.assign(fx)
	return i


func _lose(n: int) -> Effect:
	var e := LoseCoinsEffect.new(); e.amount = n; e.target = OPP; return e


func _steal(n: int) -> Effect:
	var e := StealCoinsEffect.new(); e.amount = n; return e


func _add(card: CardData, zone: GameRules.Zone) -> Effect:
	var e := AddCardEffect.new(); e.card = card; e.zone = zone; e.target = OPP; return e


func _random_curse(ids: Array) -> Effect:
	var e := AddRandomCurseEffect.new(); e.target = OPP
	var list: Array[CardData] = []
	for id in ids:
		list.append(_curse[id])
	e.curses = list
	return e


func _discard_random(n: int) -> Effect:
	var e := DiscardRandomEffect.new(); e.amount = n; e.target = OPP; return e


func _draw_lock() -> Effect:
	var e := DrawLockEffect.new(); e.target = OPP; return e


func _snatch(mode: SnatchShopCardEffect.Mode) -> Effect:
	var e := SnatchShopCardEffect.new(); e.mode = mode; return e

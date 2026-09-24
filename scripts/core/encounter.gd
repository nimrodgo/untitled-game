class_name Encounter
extends RefCounted
## The rules engine for a single encounter. UI-agnostic: the screen and the
## headless simulator both drive it through the public methods.
##
## Structure: `rounds` rounds. At round start you draw a hand. Each of your
## turns = any number of FREE actions (instant cards, using a trinket) followed
## by exactly ONE action (play a card, or buy a card/item/trinket/enhancement,
## or upgrade a trinket) — or PASS, which ends the round for you.
## The enemy doesn't play cards: after every action you take it resolves its
## next scripted intent (always visible in advance).
## After the last round you win if coins >= coin_target.

signal changed
signal logged(text: String)
## The enemy is about to resolve its intent; call enemy_act() (after a delay).
signal enemy_turn_pending
signal ended(won: bool)

var data: EncounterData
var player: PlayerState
var enemy: PlayerState
var shop := ShopState.new()
var rng := RandomNumberGenerator.new()
var round_num := 0
var active: PlayerState
var is_over := false
var won := false
var _actions_since_enemy := 0


func _init(encounter_data: EncounterData, loadout: LoadoutData) -> void:
	data = encounter_data
	if data.rng_seed != 0:
		rng.seed = data.rng_seed
	else:
		rng.randomize()

	player = PlayerState.new("You", false)
	player.coins = loadout.starting_coins
	for c in loadout.starting_deck:
		player.draw_pile.append(CardInstance.new(c))
	for it in loadout.items:
		player.items.append(ItemInstance.new(it))
	for t in loadout.trinkets:
		player.trinkets.append(TrinketInstance.new(t))

	var ed: EnemyData = data.enemy
	enemy = PlayerState.new(ed.display_name if ed else "Enemy", true)
	enemy.can_shop_items = false
	if ed:
		enemy.coins = ed.starting_coins
		enemy.intent_index = ed.start_intent
		for it in ed.items:
			enemy.items.append(ItemInstance.new(it))


func start() -> void:
	shop.setup(data, rng)
	_shuffle(player.draw_pile)
	log_line("[b]%s[/b] — have %d coins after %d rounds." % [data.display_name, data.coin_target, data.rounds])
	_fire(GameRules.Trigger.ENCOUNTER_START, player, _ctx(player))
	_fire(GameRules.Trigger.ENCOUNTER_START, enemy, _ctx(enemy))
	_start_round()


func opponent_of(p: PlayerState) -> PlayerState:
	return enemy if p == player else player


func rounds_left() -> int:
	return data.rounds - round_num + 1


func current_intent() -> EnemyIntent:
	var intents := data.enemy.intents if data.enemy else []
	if intents.is_empty():
		return null
	return intents[enemy.intent_index % intents.size()]


func upcoming_intents(count: int) -> Array[EnemyIntent]:
	var out: Array[EnemyIntent] = []
	var intents := data.enemy.intents if data.enemy else []
	for i in mini(count, intents.size()):
		out.append(intents[(enemy.intent_index + i) % intents.size()])
	return out


# ---------------------------------------------------------------- queries

func is_player_turn() -> bool:
	return not is_over and active == player


func can_play(card: CardInstance) -> bool:
	return is_player_turn() and player.hand.has(card)


func can_buy_card(slot: int) -> bool:
	if not is_player_turn() or slot < 0 or slot >= shop.cards.size():
		return false
	var c: CardData = shop.cards[slot]
	return c != null and player.coins >= c.cost


func can_buy_item(slot: int) -> bool:
	if not is_player_turn() or slot < 0 or slot >= shop.items.size():
		return false
	var it: ItemData = shop.items[slot]
	return it != null and player.coins >= it.cost


func can_buy_trinket(slot: int) -> bool:
	if not is_player_turn() or slot < 0 or slot >= shop.trinkets.size():
		return false
	var t: TrinketData = shop.trinkets[slot]
	return t != null and player.coins >= t.cost


func can_use_trinket(idx: int) -> bool:
	return is_player_turn() and idx < player.trinkets.size() and not player.trinkets[idx].used


func can_upgrade_trinket(idx: int) -> bool:
	if not is_player_turn() or idx >= player.trinkets.size():
		return false
	var t := player.trinkets[idx]
	return t.can_upgrade() and player.coins >= t.upgrade_cost()


func can_buy_enhancement(slot: int, card: CardInstance = null) -> bool:
	if not is_player_turn() or slot < 0 or slot >= shop.enhancements.size():
		return false
	var e: EnhancementData = shop.enhancements[slot]
	if e == null or player.coins < e.cost or player.hand.is_empty():
		return false
	return card == null or player.hand.has(card)


# ---------------------------------------------------------- player actions

func play_card(card: CardInstance) -> bool:
	if not can_play(card):
		return false
	var p := player
	p.hand.erase(card)
	var instant := card.is_instant()
	log_line("You play %s%s." % [_card_name(card), " (instant)" if instant else ""])
	var ctx := _ctx(p, card)
	_run(card.get_on_play(), ctx)
	p.in_play.append(card)
	_fire(GameRules.Trigger.CARD_PLAYED, p, ctx)
	_fire(GameRules.Trigger.OPPONENT_CARD_PLAYED, enemy, _ctx(enemy, card))
	if instant:
		changed.emit()
	else:
		_finish_action(ctx.grant_extra_action)
	return true


func buy_card(slot: int) -> bool:
	if not can_buy_card(slot):
		return false
	var p := player
	var cd: CardData = shop.take_card(slot)
	p.coins -= cd.cost
	p.cards_bought += 1
	p.buys_this_round += 1
	var card := CardInstance.new(cd)
	var ctx := _ctx(p, card)
	log_line("You buy %s for %d." % [_card_name(card), cd.cost])
	_fire(GameRules.Trigger.BEFORE_CARD_BUY, p, ctx)
	ctx.source_name = cd.display_name
	_run(cd.on_buy, ctx)
	_place_card(p, card, ctx.buy_destination)
	_fire(GameRules.Trigger.CARD_BOUGHT, p, ctx)
	_fire(GameRules.Trigger.OPPONENT_CARD_BOUGHT, enemy, _ctx(enemy, card))
	_after_purchase(GameRules.CARD_BUY_IS_ACTION, ctx.grant_extra_action)
	return true


func buy_item(slot: int) -> bool:
	if not can_buy_item(slot):
		return false
	var it := shop.take_item(slot)
	player.coins -= it.cost
	player.items.append(ItemInstance.new(it))
	log_line("You buy item [color=#7fe3d0]%s[/color]." % it.display_name)
	var ctx := _ctx(player)
	_fire(GameRules.Trigger.ITEM_BOUGHT, player, ctx)
	_after_purchase(GameRules.ITEM_BUY_IS_ACTION, ctx.grant_extra_action)
	return true


func buy_trinket(slot: int) -> bool:
	if not can_buy_trinket(slot):
		return false
	var t := shop.take_trinket(slot)
	player.coins -= t.cost
	player.trinkets.append(TrinketInstance.new(t))
	log_line("You buy trinket [color=#ffd166]%s[/color]." % t.display_name)
	_after_purchase(GameRules.TRINKET_BUY_IS_ACTION, false)
	return true


func upgrade_trinket(idx: int) -> bool:
	if not can_upgrade_trinket(idx):
		return false
	var t := player.trinkets[idx]
	player.coins -= t.upgrade_cost()
	t.level += 1
	log_line("You upgrade %s." % t.get_name())
	_after_purchase(GameRules.TRINKET_UPGRADE_IS_ACTION, false)
	return true


func buy_enhancement(slot: int, card: CardInstance) -> bool:
	if card == null or not can_buy_enhancement(slot, card):
		return false
	var e := shop.take_enhancement(slot)
	player.coins -= e.cost
	card.enhancements.append(e)
	log_line("You enhance %s with %s." % [_card_name(card), e.display_name])
	_after_purchase(GameRules.ENHANCEMENT_BUY_IS_ACTION, false)
	return true


## Free action.
func use_trinket(idx: int) -> bool:
	if not can_use_trinket(idx):
		return false
	var t := player.trinkets[idx]
	t.used = true
	log_line("You use %s." % t.get_name())
	var ctx := _ctx(player)
	ctx.source_name = t.data.display_name
	_run(t.current_effects(), ctx)
	_fire(GameRules.Trigger.TRINKET_USED, player, ctx)
	changed.emit()
	return true


## Ends the round for you.
func pass_turn() -> bool:
	if not is_player_turn():
		return false
	player.passed = true
	log_line("You pass.")
	_end_round()
	return true


# ------------------------------------------------------------------ enemy

## Resolve the enemy's current intent, then hand the turn back to the player.
func enemy_act() -> void:
	if is_over or active != enemy:
		return
	var intent := current_intent()
	if intent:
		log_line("[color=#ff7f6a]%s: %s[/color]" % [enemy.display_name, intent.display_name])
		var ctx := _ctx(enemy)
		ctx.source_name = intent.display_name
		_run(intent.effects, ctx)
		enemy.intent_index += 1
	_fire(GameRules.Trigger.ENEMY_ACTED, enemy, _ctx(enemy))
	_fire(GameRules.Trigger.ENEMY_ACTED, player, _ctx(player))
	_begin_player_turn()


# ------------------------------------------------ helpers used by effects

func change_coins(p: PlayerState, delta: int, source: String = "") -> void:
	var before := p.coins
	p.coins = maxi(0, p.coins + delta)
	var real := p.coins - before
	if real != 0:
		var col := "#ffd166" if real > 0 else "#ff7f6a"
		log_line("  %s [color=%s]%+d coin%s[/color]%s" % [p.display_name, col, real, "" if absi(real) == 1 else "s",
			(" (" + source + ")") if source != "" else ""])


func draw_cards(p: PlayerState, n: int) -> void:
	var drawn := 0
	for i in n:
		if p.draw_pile.is_empty():
			if p.discard.is_empty():
				break
			p.draw_pile = p.discard.duplicate()
			p.discard.clear()
			_shuffle(p.draw_pile)
		p.hand.append(p.draw_pile.pop_back())
		drawn += 1
	if drawn > 0 and round_num > 0 and not p.is_enemy:
		log_line("  %s draw %d." % [p.display_name, drawn])


func discard_random(p: PlayerState, n: int) -> void:
	for i in n:
		if p.hand.is_empty():
			return
		var c: CardInstance = p.hand.pop_at(rng.randi_range(0, p.hand.size() - 1))
		p.discard.append(c)
		log_line("  %s discard %s." % [p.display_name, _card_name(c)])


func add_card(p: PlayerState, cd: CardData, zone: GameRules.Zone) -> void:
	var c := CardInstance.new(cd)
	_place_card(p, c, zone)
	log_line("  %s gain %s." % [p.display_name, _card_name(c)])


func log_line(text: String) -> void:
	logged.emit(text)


# --------------------------------------------------------------- internals

func _start_round() -> void:
	round_num += 1
	log_line("\n[b]— Round %d / %d —[/b]" % [round_num, data.rounds])
	player.passed = false
	player.buys_this_round = 0
	for p in [player, enemy]:
		for it in p.items:
			it.uses_this_round = 0
	for t in player.trinkets:
		t.used = false
	draw_cards(player, GameRules.HAND_SIZE - player.hand.size())
	_fire(GameRules.Trigger.ROUND_START, player, _ctx(player))
	_fire(GameRules.Trigger.ROUND_START, enemy, _ctx(enemy))
	_actions_since_enemy = 0
	_begin_player_turn()


func _end_round() -> void:
	_fire(GameRules.Trigger.ROUND_END, player, _ctx(player))
	_fire(GameRules.Trigger.ROUND_END, enemy, _ctx(enemy))
	player.discard.append_array(player.in_play)
	player.in_play.clear()
	if GameRules.DISCARD_HAND_AT_ROUND_END:
		player.discard.append_array(player.hand)
		player.hand.clear()
	if round_num >= data.rounds:
		_finish_encounter()
	else:
		_start_round()


func _finish_encounter() -> void:
	is_over = true
	active = null
	won = player.coins >= data.coin_target
	log_line("\n[b]%s[/b] You have %d / %d coins." % ["VICTORY!" if won else "DEFEAT.", player.coins, data.coin_target])
	changed.emit()
	ended.emit(won)


func _begin_player_turn() -> void:
	active = player
	if GameRules.TRINKET_LIMIT == GameRules.TrinketLimit.PER_TURN:
		for t in player.trinkets:
			t.used = false
	_fire(GameRules.Trigger.TURN_START, player, _ctx(player))
	changed.emit()


func _after_purchase(is_action: bool, extra: bool) -> void:
	if is_action:
		_finish_action(extra)
	else:
		changed.emit()


func _finish_action(extra: bool) -> void:
	if is_over:
		return
	if extra:
		log_line("  You take another action.")
		changed.emit()
		return
	_actions_since_enemy += 1
	if _actions_since_enemy >= GameRules.ENEMY_ACTS_EVERY and current_intent() != null:
		_actions_since_enemy = 0
		active = enemy
		changed.emit()
		enemy_turn_pending.emit()
	else:
		_begin_player_turn()


func _fire(trigger: GameRules.Trigger, p: PlayerState, ctx: EffectContext) -> void:
	for it in p.items:
		if it.data.trigger == trigger and it.can_trigger():
			it.mark_used()
			ctx.source_name = it.data.display_name
			_run(it.data.effects, ctx)


func _run(effects: Array, ctx: EffectContext) -> void:
	for e in effects:
		if e and not is_over:
			e.apply(ctx)


func _place_card(p: PlayerState, card: CardInstance, zone: GameRules.Zone) -> void:
	match zone:
		GameRules.Zone.HAND:
			p.hand.append(card)
		GameRules.Zone.DRAW_TOP:
			p.draw_pile.append(card)
		GameRules.Zone.DISCARD:
			p.discard.append(card)
		_:
			p.draw_pile.insert(rng.randi_range(0, p.draw_pile.size()), card)


func _ctx(owner: PlayerState, card: CardInstance = null) -> EffectContext:
	var c := EffectContext.new()
	c.encounter = self
	c.owner = owner
	c.opponent = opponent_of(owner)
	c.card = card
	c.source_name = card.get_name() if card else ""
	return c


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]; arr[i] = arr[j]; arr[j] = tmp


func _card_name(c: CardInstance) -> String:
	return "[color=#9ad7ff]%s[/color]" % c.get_name()

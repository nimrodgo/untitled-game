class_name Encounter
extends RefCounted
## The rules engine for a single encounter. UI-agnostic: the screen and the
## headless simulator both drive it through the public methods.
##
## Structure: `rounds` rounds; each round is one TURN for you. You draw a hand,
## then take ACTIONS one at a time: any number of FREE ones (instant cards,
## using a trinket) and normal ones (play a card, buy a card/item/trinket/
## upgrade, upgrade a trinket). PASS ends your turn and the round.
## The enemy doesn't play cards: it answers each of your normal actions with
## its next scripted intent (always visible), up to actions_per_round times.
## The market restocks at the start of each round.
## After the last round you win if coins >= coin_target.
##
## Choices: effects can ask the player to decide something (pick cards, pick
## an option...) with `await request_choice(req)`. While a choice is pending,
## `pending_choice` is set and `choice_requested` fires; the UI answers with
## `submit_choice(picks)`. Headless code sets `auto_chooser` instead, which
## answers immediately. Because of this, every action runs as a coroutine:
## the public action methods validate, start it and return true right away.

signal changed
signal logged(text: String)
## The enemy is about to resolve its intent; call enemy_act() (after a delay).
signal enemy_turn_pending
signal ended(won: bool)
## The player must decide something: answer with submit_choice().
signal choice_requested(req: ChoiceRequest)
signal _choice_made(picks: Array)

var data: EncounterData
var player: PlayerState
var enemy: PlayerState
var shop := ShopState.new()
var rng := RandomNumberGenerator.new()
var round_num := 0
var active: PlayerState
var is_over := false
var won := false
## Enemy intents still available this round.
var enemy_actions_left := 0
## Where the most recently bought card went (the UI animates it there).
var last_bought_zone: GameRules.Zone = GameRules.DEFAULT_BUY_DESTINATION
## Rounds added by effects ("take an extra turn").
var extra_rounds := 0
## The decision the player has to make right now (null = none).
var pending_choice: ChoiceRequest
## If valid, called with a ChoiceRequest and must return the picks
## synchronously (used by the simulator / tests).
var auto_chooser: Callable

## >0 while an action is resolving (no new actions can start).
var _busy := 0
## Flags collected from effect contexts during the current action.
var _act_extra := false
var _act_pass := false


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
	if ed:
		enemy.coins = ed.starting_coins
		enemy.intent_index = ed.start_intent
		for it in ed.items:
			enemy.items.append(ItemInstance.new(it))


func start() -> void:
	shop.trinket_weight = _trinket_weight
	shop.setup(data, rng)
	_shuffle(player.draw_pile)
	log_line("[b]%s[/b] — have %d coins after %d rounds." % [data.display_name, data.coin_target, data.rounds])
	_start_async()


func _start_async() -> void:
	_busy += 1
	await _fire(GameRules.Trigger.ENCOUNTER_START, player, _ctx(player))
	await _fire(GameRules.Trigger.ENCOUNTER_START, enemy, _ctx(enemy))
	_busy -= 1
	await _start_round()


func opponent_of(p: PlayerState) -> PlayerState:
	return enemy if p == player else player


func total_rounds() -> int:
	return data.rounds + extra_rounds


func rounds_left() -> int:
	return total_rounds() - round_num + 1


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

## True when the player can start a new action.
func is_player_turn() -> bool:
	return not is_over and active == player and _busy == 0 and pending_choice == null


## True while something is resolving (an action, a choice, the enemy).
func is_busy() -> bool:
	return _busy > 0 or pending_choice != null


func can_play(card: CardInstance) -> bool:
	if not is_player_turn() or not player.hand.has(card) or not card.data.playable:
		return false
	var ctx := _ctx(player, card)
	for e in card.get_on_play():
		if e and not e.can_pay(ctx):
			return false
	return true


func can_buy_card(slot: int) -> bool:
	if not is_player_turn() or slot < 0 or slot >= shop.cards.size():
		return false
	var c: CardData = shop.cards[slot]
	return c != null and player.coins >= card_price(player, c.cost)


## What buying a card with base cost `base` costs `p` right now (items such as
## Needful override it). The lowest override wins.
func card_price(p: PlayerState, base: int) -> int:
	var price := base
	for it in p.items:
		var o: int = it.data.card_price_override
		if o >= 0 and o < price:
			price = o
	return price


func can_buy_item(slot: int) -> bool:
	if not is_player_turn() or slot < 0 or slot >= shop.items.size():
		return false
	var it: ItemData = shop.items[slot]
	return it != null and player.coins >= it.cost


## Buying a trinket you already own upgrades it (for its next upgrade cost);
## a new one needs a free slot (GameRules.MAX_TRINKETS).
func can_buy_trinket(slot: int) -> bool:
	if not is_player_turn() or slot < 0 or slot >= shop.trinkets.size():
		return false
	var t: TrinketData = shop.trinkets[slot]
	if t == null:
		return false
	var owned := owned_trinket(t)
	if owned:
		return owned.can_upgrade() and player.coins >= owned.upgrade_cost()
	return player.trinkets.size() < GameRules.MAX_TRINKETS and player.coins >= t.cost


## Your copy of this trinket, or null.
func owned_trinket(td: TrinketData) -> TrinketInstance:
	for t in player.trinkets:
		if t.data == td or (td.id != &"" and t.data.id == td.id):
			return t
	return null


## What buying this market trinket would cost you right now.
func trinket_buy_cost(td: TrinketData) -> int:
	var owned := owned_trinket(td)
	return owned.upgrade_cost() if owned and owned.can_upgrade() else td.cost


func can_sell_trinket(idx: int) -> bool:
	return is_player_turn() and idx >= 0 and idx < player.trinkets.size()


func _trinket_weight(td: TrinketData) -> float:
	var owned := owned_trinket(td)
	if owned == null:
		return 1.0
	return 2.0 if owned.can_upgrade() else 0.0


func can_use_trinket(idx: int) -> bool:
	if not is_player_turn() or idx >= player.trinkets.size() or player.trinkets[idx].used:
		return false
	var ctx := _ctx(player)
	for e in player.trinkets[idx].current_effects():
		if e and not e.can_pay(ctx):
			return false
	return true


func can_buy_enhancement(slot: int, card: CardInstance = null) -> bool:
	if not is_player_turn() or slot < 0 or slot >= shop.enhancements.size():
		return false
	var e: EnhancementData = shop.enhancements[slot]
	if e == null or player.coins < e.cost:
		return false
	if card != null:
		return player.hand.has(card) and _can_enhance(card, e)
	for c in player.hand:
		if _can_enhance(c, e):
			return true
	return false


## One enhancement per card: an enhanced card can't take another. (An enhancement
## that only destroys the card, like Trim's, attaches nothing, so it can still be used.)
func _can_enhance(card: CardInstance, e: EnhancementData) -> bool:
	return card.enhancement == null or e.destroy_on_apply


# ---------------------------------------------------------- player actions
# Each validates, starts the action coroutine and returns true at once.

func play_card(card: CardInstance) -> bool:
	if not can_play(card):
		return false
	_play_from_hand(card)
	return true


func buy_card(slot: int) -> bool:
	if not can_buy_card(slot):
		return false
	_buy_from_market(slot)
	return true


func buy_item(slot: int) -> bool:
	if not can_buy_item(slot):
		return false
	_buy_item(slot)
	return true


func buy_trinket(slot: int) -> bool:
	if not can_buy_trinket(slot):
		return false
	var td := shop.take_trinket(slot)
	var owned := owned_trinket(td)
	if owned:
		var cost := owned.upgrade_cost()
		player.coins -= cost
		owned.paid += cost
		owned.level += 1
		owned.used = false   # an upgrade refreshes the trinket
		log_line("You upgrade trinket [color=#ffd166]%s[/color] (refreshed)." % owned.get_name())
	else:
		player.coins -= td.cost
		player.trinkets.append(TrinketInstance.new(td))
		log_line("You buy trinket [color=#ffd166]%s[/color]." % td.display_name)
	_begin_action()
	_finish_action_if(GameRules.TRINKET_BUY_IS_ACTION, false)
	return true


## Sell a trinket for half of everything you paid for it (rounded down).
## A free action by default (GameRules.TRINKET_SELL_IS_ACTION).
func sell_trinket(idx: int) -> bool:
	if not can_sell_trinket(idx):
		return false
	var t := player.trinkets[idx]
	player.trinkets.remove_at(idx)
	log_line("You sell trinket [color=#ffd166]%s[/color]." % t.get_name())
	change_coins(player, t.sell_value(), "sale")
	_begin_action()
	_finish_action_if(GameRules.TRINKET_SELL_IS_ACTION, false)
	return true


func buy_enhancement(slot: int, card: CardInstance) -> bool:
	if card == null or not can_buy_enhancement(slot, card):
		return false
	_buy_enhancement(slot, card)
	return true


## Free action.
func use_trinket(idx: int) -> bool:
	if not can_use_trinket(idx):
		return false
	_use_trinket(idx)
	return true


## Ends the round for you.
func pass_turn() -> bool:
	if not is_player_turn():
		return false
	_pass()
	return true


## Answer the pending choice. `picks` holds chosen candidates (OPTIONS: the
## option index). Returns false if the answer isn't valid.
func submit_choice(picks: Array) -> bool:
	var req := pending_choice
	if req == null or not _valid_picks(req, picks):
		return false
	pending_choice = null
	_choice_made.emit(picks)
	return true


# ------------------------------------------------------------------ enemy

## Resolve the enemy's current intent, then hand the turn back to the player.
func enemy_act() -> void:
	if is_over or active != enemy or _busy > 0:
		return
	_busy += 1
	var intent := current_intent()
	if intent:
		log_line("[color=#ff7f6a]%s: %s[/color]" % [enemy.display_name, intent.display_name])
		var ctx := _ctx(enemy)
		ctx.source_name = intent.display_name
		await _run(intent.effects, ctx)
		enemy.intent_index += 1
		enemy_actions_left -= 1
	await _fire(GameRules.Trigger.ENEMY_ACTED, enemy, _ctx(enemy))
	await _fire(GameRules.Trigger.ENEMY_ACTED, player, _ctx(player))
	_busy -= 1
	_await_player_action()


# ------------------------------------------------ choices (used by effects)

## Ask the player to decide. Returns the picks (see ChoiceRequest).
## Requests with nothing to choose from resolve immediately.
func request_choice(req: ChoiceRequest) -> Array:
	if req.kind != ChoiceRequest.Kind.OPTIONS:
		req.max_count = mini(req.max_count, req.candidates.size())
		req.min_count = mini(req.min_count, req.max_count)
		if req.max_count <= 0:
			return []
		# Mandatory and no real choice: take everything.
		if req.min_count == req.candidates.size():
			return req.candidates.duplicate()
	if req.kind == ChoiceRequest.Kind.CARDS:
		req.hand_only = true
		for c in req.candidates:
			if not player.hand.has(c):
				req.hand_only = false
				break
	if auto_chooser.is_valid():
		var auto_picks: Array = auto_chooser.call(req)
		if not _valid_picks(req, auto_picks):
			push_error("auto_chooser gave an invalid answer for %s" % req.verb)
			auto_picks = _default_picks(req)
		return auto_picks
	pending_choice = req
	changed.emit()
	choice_requested.emit(req)
	var picks: Array = await _choice_made
	changed.emit()
	return picks


func _valid_picks(req: ChoiceRequest, picks: Array) -> bool:
	if req.kind == ChoiceRequest.Kind.OPTIONS:
		return picks.size() == 1 and picks[0] is int and picks[0] >= 0 and picks[0] < req.candidates.size() \
			and (req.enabled.is_empty() or req.enabled[picks[0]])
	if picks.size() < req.min_count or picks.size() > req.max_count:
		return false
	var seen := {}
	for p in picks:
		if not req.candidates.has(p) or seen.has(p):
			return false
		seen[p] = true
	return true


func _default_picks(req: ChoiceRequest) -> Array:
	if req.kind == ChoiceRequest.Kind.OPTIONS:
		for i in req.candidates.size():
			if req.enabled.is_empty() or req.enabled[i]:
				return [i]
		return [0]
	return req.candidates.slice(0, req.min_count)


## Helper for effects: pick `amount` cards from the given piles (PILE_* flags).
func choose_cards(p: PlayerState, piles: int, amount: int, verb: String, ctx: EffectContext,
		optional := false, filter := Callable(), exclude: CardInstance = null) -> Array:
	var cands: Array = []
	var groups: Array = []
	for pair in [[GameRules.PILE_HAND, p.hand, "Hand"], [GameRules.PILE_DRAW, p.draw_pile, "Deck"],
			[GameRules.PILE_DISCARD, p.discard, "Discard"]]:
		if piles & pair[0]:
			for c in pair[1]:
				if c != exclude and (not filter.is_valid() or filter.call(c)):
					cands.append(c)
					groups.append(pair[2])
	var req := ChoiceRequest.new()
	req.kind = ChoiceRequest.Kind.CARDS
	req.verb = verb
	req.candidates = cands
	req.groups = groups
	req.max_count = amount
	req.min_count = 0 if optional else amount
	req.source_name = ctx.source_name
	req.source_card = ctx.card
	return await request_choice(req)


# ------------------------------------------------ helpers used by effects

func change_coins(p: PlayerState, delta: int, source: String = "") -> void:
	var before := p.coins
	p.coins = maxi(0, p.coins + delta)
	var real := p.coins - before
	if real != 0:
		var col := "#ffd166" if real > 0 else "#ff7f6a"
		log_line("  %s [color=%s]%+d coin%s[/color]%s" % [p.display_name, col, real, "" if absi(real) == 1 else "s",
			(" (" + source + ")") if source != "" else ""])


## Draw from the top (or `from_bottom`) of the draw pile. The discard pile is
## never reshuffled mid-turn: if the deck runs out you just draw what's there
## (the discard pile goes under the deck at the end of every turn).
func draw_cards(p: PlayerState, n: int, from_bottom := false, opening := false) -> int:
	var drawn := 0
	for i in n:
		if is_over or (p.draw_locked and not opening):
			break
		if p.draw_pile.is_empty():
			break
		var c: CardInstance = p.draw_pile.pop_front() if from_bottom else p.draw_pile.pop_back()
		p.hand.append(c)
		drawn += 1
		p.cards_drawn_this_turn += 1
		await _after_draw(p, c, opening)
	if drawn > 0 and round_num > 0 and not p.is_enemy and not opening:
		log_line("  %s draw %d." % [p.display_name, drawn])
	return drawn


## Draw one specific card (from the discard pile, the market...) into the hand.
func draw_specific(p: PlayerState, c: CardInstance) -> bool:
	if p.draw_locked:
		return false
	_take_from_piles(p, c)
	p.hand.append(c)
	p.cards_drawn_this_turn += 1
	log_line("  %s draw %s." % [p.display_name, _card_name(c)])
	await _after_draw(p, c, false)
	return true


func _after_draw(p: PlayerState, c: CardInstance, opening: bool) -> void:
	var ctx := _ctx(p, c)
	ctx.opening_draw = opening
	await _fire(GameRules.Trigger.CARD_DRAWN, p, ctx)
	if c.is_curse():
		var cctx := _ctx(p, c)
		cctx.opening_draw = opening
		await _fire(GameRules.Trigger.CURSE_DRAWN, p, cctx)


func discard_random(p: PlayerState, n: int) -> void:
	var picks: Array = []
	var pool := p.hand.duplicate()
	for i in mini(n, pool.size()):
		picks.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	await discard_cards(p, picks)


## Discard specific cards (from the hand, or e.g. the top of the deck).
## Fires the card's on_discard and CARD_DISCARDED for each.
func discard_cards(p: PlayerState, cards: Array) -> void:
	for c in cards:
		if not _take_from_piles(p, c):
			continue
		p.discard.append(c)
		log_line("  %s discard %s." % [p.display_name, _card_name(c)])
		var ctx := _ctx(p, c)
		var on_discard: Array[Effect] = c.get_on_discard()
		if not on_discard.is_empty():
			await _run(on_discard, ctx)
		await _fire(GameRules.Trigger.CARD_DISCARDED, p, _ctx(p, c))


## Remove a card for the encounter (`destroy` = false) or destroy it
## permanently. Works wherever the card is, including a card being played.
func trash_card(p: PlayerState, c: CardInstance, destroy: bool) -> void:
	if p.removed.has(c) or p.destroyed.has(c):
		return
	var from := _pile_of(p, c)
	_take_from_piles(p, c)
	c.retain = false
	if destroy:
		p.destroyed.append(c)
	else:
		p.removed.append(c)
	log_line("  %s %s %s." % [p.display_name, "destroy" if destroy else "remove", _card_name(c)])
	var ctx := _ctx(p, c)
	ctx.from_pile = from
	if destroy and not c.data.on_destroy.is_empty():
		await _run(c.data.on_destroy, ctx)
	await _fire(GameRules.Trigger.CARD_DESTROYED if destroy else GameRules.Trigger.CARD_REMOVED, p, ctx)
	if from == GameRules.PILE_HAND:
		await _fire(GameRules.Trigger.CARD_TRASHED_FROM_HAND, p, ctx)


func add_card(p: PlayerState, cd: CardData, zone: GameRules.Zone) -> void:
	var c := CardInstance.new(cd)
	_place_card(p, c, zone)
	log_line("  %s gain %s." % [p.display_name, _card_name(c)])


## Move a card you own to `zone` (no triggers).
func move_card(p: PlayerState, c: CardInstance, zone: GameRules.Zone) -> void:
	_take_from_piles(p, c)
	_place_card(p, c, zone)


## Play a card that isn't coming from your hand (e.g. from the top of the
## deck). It counts as playing a card.
func play_extra(p: PlayerState, c: CardInstance) -> void:
	_take_from_piles(p, c)
	log_line("  %s play %s." % [p.display_name, _card_name(c)])
	await _play(p, c, false)


## Resolve a card's on-play effects again without moving it (replays and
## "play the effect of..."). Counts as playing a card.
func play_copy(p: PlayerState, c: CardInstance) -> void:
	log_line("  %s play %s again." % [p.display_name, _card_name(c)])
	await _resolve_play(p, c, false)


## Buy a card instance from anywhere (market, removed, destroyed pile...).
## Pays `cost`, resolves on-buy + buy triggers. If `place` is false the card
## is left out of every pile (the caller decides where it goes).
func buy_instance(p: PlayerState, card: CardInstance, cost: int, zone_override := -1, place := true) -> void:
	p.coins -= cost
	p.cards_bought += 1
	p.buys_this_round += 1
	var ctx := _ctx(p, card)
	log_line("%s buy %s for %d." % [p.display_name, _card_name(card), cost])
	await _fire(GameRules.Trigger.BEFORE_CARD_BUY, p, ctx)
	ctx.source_name = card.data.display_name
	await _run(card.data.on_buy, ctx)
	var dest := ctx.buy_destination
	var drawn := false
	if zone_override >= 0:
		dest = zone_override as GameRules.Zone
	elif p.next_buy_to_hand > 0 and not p.draw_locked:
		p.next_buy_to_hand -= 1
		drawn = true
		dest = GameRules.Zone.HAND
	if place:
		if drawn:
			await draw_specific(p, card)
		else:
			_place_card(p, card, dest)
			log_line("  %s %s." % [_card_name(card), _zone_phrase(dest)])
		last_bought_zone = dest
	await _fire(GameRules.Trigger.CARD_BOUGHT, p, ctx)
	await _fire(GameRules.Trigger.OPPONENT_CARD_BOUGHT, opponent_of(p), _ctx(opponent_of(p), card))
	_absorb(ctx)


## Run a list of effects for `ctx`'s owner (trinkets in the shop, copies...).
func run_effects(effects: Array, ctx: EffectContext) -> void:
	await _run(effects, ctx)


## Live values card text can show with {name} placeholders.
func text_vars(p: PlayerState = null) -> Dictionary:
	if p == null:
		p = player
	return {
		"cards_drawn_this_turn": p.cards_drawn_this_turn,
		"cards_drawn_this_round": p.cards_drawn_this_turn,
		"cards_played_this_turn": p.cards_played_this_turn,
		"cards_played_this_round": p.cards_played_this_turn,
		"coins": p.coins,
		"round": round_num,
		"removed": p.removed.size(),
		"destroyed": p.destroyed.size(),
	}


func log_line(text: String) -> void:
	logged.emit(text)


# --------------------------------------------------------- action bodies

func _begin_action() -> void:
	_act_extra = false
	_act_pass = false


func _play_from_hand(card: CardInstance) -> void:
	_busy += 1
	_begin_action()
	var p := player
	p.hand.erase(card)
	var instant := card.is_instant()
	log_line("You play %s%s." % [_card_name(card), " (instant)" if instant else ""])
	await _play(p, card, true)
	_busy -= 1
	if instant and not _act_pass:
		changed.emit()
	else:
		await _finish_action(_act_extra)


## Play a card that is in no pile yet: resolve it (plus pending replays),
## then it goes to the discard pile unless its effects moved it somewhere else.
func _play(p: PlayerState, card: CardInstance, _from_hand: bool) -> void:
	var replays := p.replay_next
	p.replay_next = 0
	await _resolve_play(p, card, true)
	for i in replays:
		if is_over:
			break
		await play_copy(p, card)


func _resolve_play(p: PlayerState, card: CardInstance, first: bool) -> void:
	var ctx := _ctx(p, card)
	p.cards_played_this_turn += 1
	await _run(card.get_on_play(), ctx)
	p.played_log.append(card)
	if first and _pile_of(p, card) == 0 and not p.removed.has(card) and not p.destroyed.has(card):
		p.discard.append(card)
	await _fire(GameRules.Trigger.CARD_PLAYED, p, ctx)
	var o := opponent_of(p)
	await _fire(GameRules.Trigger.OPPONENT_CARD_PLAYED, o, _ctx(o, card))


func _buy_from_market(slot: int) -> void:
	_busy += 1
	_begin_action()
	var cd: CardData = shop.take_card(slot)
	await buy_instance(player, CardInstance.new(cd), card_price(player, cd.cost))
	_busy -= 1
	await _finish_action_if(GameRules.CARD_BUY_IS_ACTION, _act_extra)


func _buy_enhancement(slot: int, card: CardInstance) -> void:
	_busy += 1
	_begin_action()
	var e := shop.take_enhancement(slot)
	player.coins -= e.cost
	if e.destroy_on_apply:
		log_line("You use %s on %s." % [e.display_name, _card_name(card)])
		await trash_card(player, card, true)
	else:
		card.enhancement = e
		log_line("You enhance %s with %s." % [_card_name(card), e.display_name])
	_busy -= 1
	await _finish_action_if(GameRules.ENHANCEMENT_BUY_IS_ACTION, false)


func _buy_item(slot: int) -> void:
	_busy += 1
	_begin_action()
	var it := shop.take_item(slot)
	player.coins -= it.cost
	player.items.append(ItemInstance.new(it))
	log_line("You buy item [color=#7fe3d0]%s[/color]." % it.display_name)
	await _fire(GameRules.Trigger.ITEM_BOUGHT, player, _ctx(player))
	_busy -= 1
	await _finish_action_if(GameRules.ITEM_BUY_IS_ACTION, _act_extra)


func _use_trinket(idx: int) -> void:
	_busy += 1
	_begin_action()
	var t := player.trinkets[idx]
	t.used = true
	log_line("You use %s." % t.get_name())
	var ctx := _ctx(player)
	ctx.source_name = t.data.display_name
	await _run(t.current_effects(), ctx)
	await _fire(GameRules.Trigger.TRINKET_USED, player, ctx)
	_busy -= 1
	if _act_pass:
		await _pass()
	else:
		changed.emit()


func _pass() -> void:
	if is_over:
		return
	_act_pass = false
	log_line("You pass.")
	await _end_round()


# --------------------------------------------------------------- internals

func _start_round() -> void:
	_busy += 1
	round_num += 1
	log_line("\n[b]— Round %d / %d —[/b]" % [round_num, total_rounds()])
	player.buys_this_round = 0
	player.draw_locked = false
	player.played_log.clear()
	if round_num > 1:
		shop.restock()
		log_line("  The market restocks.")
	for p in [player, enemy]:
		for it in p.items:
			it.uses_this_round = 0
	for t in player.trinkets:
		t.used = false
	# Retained cards stay on top of a full new hand.
	var n := GameRules.HAND_SIZE
	if not GameRules.DISCARD_HAND_AT_ROUND_END:
		n = maxi(0, GameRules.HAND_SIZE - player.hand.size())
	n += player.bonus_draw_next_turn
	player.bonus_draw_next_turn = 0
	await draw_cards(player, n, false, true)
	await _fire(GameRules.Trigger.HAND_DRAWN, player, _opening_ctx())
	# New turn: the opening hand doesn't count as "drawn this turn".
	player.cards_drawn_this_turn = 0
	player.cards_played_this_turn = 0
	enemy_actions_left = data.enemy.actions_per_round if data.enemy else 0
	await _fire(GameRules.Trigger.ROUND_START, player, _ctx(player))
	await _fire(GameRules.Trigger.ROUND_START, enemy, _ctx(enemy))
	await _fire(GameRules.Trigger.TURN_START, player, _ctx(player))
	_busy -= 1
	_await_player_action()


func _opening_ctx() -> EffectContext:
	var c := _ctx(player)
	c.opening_draw = true
	return c


func _end_round() -> void:
	_busy += 1
	await _fire(GameRules.Trigger.ROUND_END, player, _ctx(player))
	await _fire(GameRules.Trigger.ROUND_END, enemy, _ctx(enemy))
	# Cards that punish you for holding them.
	for c in player.hand.duplicate():
		if not c.data.on_turn_end_in_hand.is_empty() and player.hand.has(c):
			var ctx := _ctx(player, c)
			await _run(c.data.on_turn_end_in_hand, ctx)
	if GameRules.DISCARD_HAND_AT_ROUND_END:
		var keep: Array[CardInstance] = []
		for c in player.hand:
			if c.is_retained():
				keep.append(c)
			else:
				player.discard.append(c)
		player.hand = keep
	for c in player.hand:
		c.retain = false
	_cycle_discard_under_deck(player)
	_busy -= 1
	if round_num >= total_rounds():
		_finish_encounter()
	else:
		await _start_round()


## End of turn: shuffle the discard pile and put it at the bottom of the deck.
## (draw_pile[0] is the bottom, draw_pile.back() the top.)
func _cycle_discard_under_deck(p: PlayerState) -> void:
	if p.discard.is_empty():
		return
	var moved := p.discard.duplicate()
	p.discard.clear()
	_shuffle(moved)
	moved.append_array(p.draw_pile)
	p.draw_pile.assign(moved)
	log_line("  The discard pile is shuffled under your deck (%d cards)." % moved.size())


func _finish_encounter() -> void:
	is_over = true
	active = null
	won = player.coins >= data.coin_target
	log_line("\n[b]%s[/b] You have %d / %d coins." % ["VICTORY!" if won else "DEFEAT.", player.coins, data.coin_target])
	changed.emit()
	ended.emit(won)


func _await_player_action() -> void:
	if is_over:
		return
	active = player
	if GameRules.TRINKET_LIMIT == GameRules.TrinketLimit.PER_ACTION:
		for t in player.trinkets:
			t.used = false
	changed.emit()


func _finish_action_if(is_action: bool, extra: bool) -> void:
	if is_action or _act_pass:
		await _finish_action(extra)
	else:
		changed.emit()


func _finish_action(extra: bool) -> void:
	if is_over:
		return
	if _act_pass:
		await _pass()
		return
	if extra:
		log_line("  You take another action.")
		changed.emit()
		return
	if enemy_actions_left > 0 and current_intent() != null:
		active = enemy
		changed.emit()
		enemy_turn_pending.emit()
	else:
		_await_player_action()


func _fire(trigger: GameRules.Trigger, p: PlayerState, ctx: EffectContext) -> void:
	for it in p.items.duplicate():
		if is_over:
			return
		if it.data.trigger == trigger and it.can_trigger():
			it.mark_used()
			ctx.source_name = it.data.display_name
			ctx.declined = false
			await _run(it.data.effects, ctx)
			if ctx.declined:
				it.uses_this_round -= 1
				it.uses_this_encounter -= 1
				ctx.declined = false


func _run(effects: Array, ctx: EffectContext) -> void:
	for e in effects:
		if e and not is_over:
			await e.apply(ctx)
	_absorb(ctx)


## Collect "take another action" / "pass" requests from the player's effects.
func _absorb(ctx: EffectContext) -> void:
	if ctx.owner == player:
		_act_extra = _act_extra or ctx.grant_extra_action
		_act_pass = _act_pass or ctx.pass_after


## Which of p's piles holds c (GameRules.PILE_*; 0 = none).
func _pile_of(p: PlayerState, c: CardInstance) -> int:
	if p.hand.has(c): return GameRules.PILE_HAND
	if p.draw_pile.has(c): return GameRules.PILE_DRAW
	if p.discard.has(c): return GameRules.PILE_DISCARD
	return 0


func _take_from_piles(p: PlayerState, c: CardInstance) -> bool:
	for pile in [p.hand, p.draw_pile, p.discard, p.removed, p.destroyed]:
		if pile.has(c):
			pile.erase(c)
			return true
	return false


func _place_card(p: PlayerState, card: CardInstance, zone: GameRules.Zone) -> void:
	match zone:
		GameRules.Zone.HAND:
			p.hand.append(card)
		GameRules.Zone.DRAW_TOP:
			p.draw_pile.append(card)
		GameRules.Zone.DISCARD:
			p.discard.append(card)
		GameRules.Zone.DRAW_BOTTOM:
			p.draw_pile.insert(0, card)


func _zone_phrase(zone: GameRules.Zone) -> String:
	match zone:
		GameRules.Zone.HAND: return "goes to your hand"
		GameRules.Zone.DRAW_TOP: return "goes on top of your deck"
		GameRules.Zone.DISCARD: return "goes to your discard pile"
	return "goes to the bottom of your deck"


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

extends Control
## Landscape (mobile-friendly) encounter screen, built in code so it's easy to
## swap for real scenes/art later. Talks only to Encounter.
##
## Interaction model (communicated with motion/highlights, not text):
## - Drag a card out of your hand to play it (it glows gold once releasing
##   would play it, then pops in the middle of the table).
## - Drag a market card onto your deck to buy it; drag items / trinkets onto
##   your Items / Trinkets slots. Valid targets pulse; the hovered one glows.
## - Tap anything to inspect it (popup with the same actions as buttons).

@export var encounter_data: EncounterData
## If not empty, each run picks one of these at random (encounter_data is the
## fallback). "Play again" reloads the scene, so it rolls again.
@export var encounter_pool: Array[EncounterData] = []
@export var loadout: LoadoutData


const LARGE_W := 340.0

var enc: Encounter
var pending_enh_slot := -1

var _round_label: Label
var _coins_label: Label
var _coins_bar: ProgressBar
var _enemy_name: Label
var _enemy_sub: RichTextLabel
var _enemy_portrait_label: Label
var _enemy_portrait: PanelContainer
var _enemy_chips: HBoxContainer
var _enemy_pips: HBoxContainer
var _intent_bubble: PanelContainer
var _intent_title: Label
var _intent_kind: Label
var _intent_desc: RichTextLabel
var _intent_cross: Control
var _shop_panel: DropTarget      ## the market; also where you drag a trinket to sell it
var _sell_drag := {}
var _shop_row: VBoxContainer        ## market lines: cards, then items/trinkets
var _shop_cards_row: HBoxContainer  ## the card group (for enemy snatch fx)
var _table_hint: Button        ## only shown while picking a card to upgrade (tap = cancel)
var _trinkets_panel: DropTarget
var _trinkets_box: VBoxContainer
var _items_panel: DropTarget
var _items_box: VBoxContainer
var _rotate_overlay: Control
var _hand: HandView
var _pile: PileView
var _pass_btn: Button
var _fs_button: Button
var _install_button: Button
var _margin: MarginContainer
var _snap_again_pending := false
var _fx_layer: Control
var _popup_layer: Control
var _hover_layer: Control
var _hover_owner: Control
var _log_text := ""
var _enemy_timer: Timer
var _shop_drag := {}
var _last_coins := -1
var _last_enemy_coins := -1
var _last_round := 0
## The choice being answered (see Encounter.request_choice) and the picks so far.
var _choice: ChoiceRequest
var _picked: Array = []
var _choice_bar: PanelContainer
var _choice_label: RichTextLabel
var _choice_ok: Button
var _picker_views := {}
var _picker_ok: Button


func _ready() -> void:
	_build_ui()
	_enemy_timer = Timer.new()
	_enemy_timer.one_shot = true
	_enemy_timer.wait_time = GameRules.ENEMY_STEP_DELAY
	_enemy_timer.timeout.connect(_on_enemy_timer)
	add_child(_enemy_timer)

	if not encounter_pool.is_empty():
		encounter_data = encounter_pool.pick_random()
	if encounter_data == null or loadout == null:
		push_error("Assign encounter_pool (or encounter_data) and loadout on the Main node.")
		return
	enc = Encounter.new(encounter_data, loadout)
	enc.logged.connect(func(t: String): _log_text += t + "\n")
	enc.changed.connect(_refresh)
	enc.enemy_turn_pending.connect(_on_enemy_pending)
	enc.ended.connect(_show_end_overlay)
	enc.choice_requested.connect(_on_choice_requested)
	# Let the layout settle so cards can deal in from the deck.
	await get_tree().process_frame
	_hand.spawn_point = _pile.target_center()
	enc.start()


# ================================================================== flow

func _on_enemy_pending() -> void:
	var tw := _intent_bubble.create_tween()
	_intent_bubble.pivot_offset = _intent_bubble.size * 0.5
	tw.tween_property(_intent_bubble, "scale", Vector2(1.12, 1.12), 0.2).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_intent_bubble, "scale", Vector2.ONE, 0.25)
	_enemy_timer.start()


func _on_enemy_timer() -> void:
	if enc == null:
		return
	# Remember the market so we can show what the enemy takes.
	var before := enc.shop.cards.duplicate()
	var rects := []
	if _shop_cards_row:
		for c in _shop_cards_row.get_children():
			rects.append((c as Control).get_global_rect())
	enc.enemy_act()
	if true:
		for i in mini(before.size(), rects.size()):
			if before[i] != null and enc.shop.cards[i] != before[i]:
				var ghost := _card_data_view(before[i], CardView.SMALL)
				_add_fx(ghost, rects[i].get_center())
				Fx.fly_into(ghost, _enemy_portrait.get_global_rect().get_center(), Callable(), 0.55)


func _on_card_dropped(card: Variant, at_global: Vector2) -> void:
	if pending_enh_slot >= 0 or _choice:
		_hand._layout(true, [])
		return
	_play_with_fx(card, at_global)


func _play_with_fx(card: CardInstance, from_global: Vector2) -> void:
	var ghost := _card_instance_view(card, CardView.HAND)
	if not enc.play_card(card):
		ghost.free()
		_hand._layout(true, [])
		return
	_add_fx(ghost, from_global)
	Fx.resolve(ghost, _table_center())


func _on_hand_tapped(card: Variant) -> void:
	var c: CardInstance = card
	if _choice and _choice.hand_only:
		_toggle_pick(c)
		return
	if pending_enh_slot >= 0:
		var slot := pending_enh_slot
		pending_enh_slot = -1
		if not enc.buy_enhancement(slot, c):
			_refresh()
		return
	_show_popup(_card_instance_view(c, CardView.LARGE), c.data.flavor_text, [
		{"label": "Play", "icon": "⚡" if c.is_instant() else "", "enabled": enc.can_play(c),
			"cb": func(): _play_with_fx(c, _hand.card_center(c))},
	])


## Adds `view` to the effects layer centred on `center_global`.
func _add_fx(view: Control, center_global: Vector2) -> void:
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if view is CardView:
		(view as CardView).hoverable = false
	_fx_layer.add_child(view)
	view.size = view.custom_minimum_size
	view.global_position = center_global - view.size * 0.5


# =============================================================== refresh

func _refresh() -> void:
	if enc == null:
		return
	_hide_legend()
	var me := enc.player
	var my_turn := enc.is_player_turn()

	# Top bar + coin change pop-ups.
	_round_label.text = "Round %d/%d" % [enc.round_num, enc.total_rounds()]
	_coins_label.text = "%d / %d" % [me.coins, enc.coin_target()]
	_coins_bar.max_value = maxi(1, enc.coin_target())
	_coins_bar.value = mini(me.coins, enc.coin_target())
	_coin_pop(_coins_label, _last_coins, me.coins)
	_coin_pop(_enemy_sub, _last_enemy_coins, enc.enemy.coins)
	_last_coins = me.coins
	_last_enemy_coins = enc.enemy.coins
	if enc.round_num != _last_round:
		_last_round = enc.round_num
		_round_banner("Round %d" % enc.round_num)
		# Market restocked: fade the new stock in.
		_shop_row.modulate.a = 0.0
		_shop_row.create_tween().tween_property(_shop_row, "modulate:a", 1.0, 0.5).set_delay(0.3)

	# Enemy.
	_enemy_name.text = enc.enemy.display_name
	_enemy_sub.clear()
	Icons.append(_enemy_sub, "%d 🪙" % enc.enemy.coins, 18)
	_enemy_portrait_label.text = enc.enemy.display_name.get_slice(" ", enc.enemy.display_name.get_slice_count(" ") - 1).left(1)
	var ecol: Color = enc.data.enemy.color if enc.data.enemy else Palette.CORAL
	_enemy_portrait.add_theme_stylebox_override("panel", Palette.box(ecol.darkened(0.5), ecol, 48, 3, 0))
	var intent := enc.current_intent()
	_intent_desc.clear()
	# A cancel card is waiting: the next intent is shown struck through.
	var cancelled := intent != null and enc.player.cancel_opponent_actions > 0 and enc.enemy_actions_left > 0
	if intent:
		_intent_title.text = intent.display_name
		_intent_kind.text = "NEXT · " + EnemyIntent.kind_label(intent.kind)
		Icons.append(_intent_desc, ("[s]%s[/s]" if cancelled else "%s") % intent.get_description(), 19)
	else:
		_intent_title.text = "—"
	_intent_title.add_theme_color_override("font_color", Palette.MUTED if cancelled else Palette.FOAM)
	_intent_cross.visible = cancelled
	# Actions left this round: filled pips; the intent fades once it's spent.
	var total_actions: int = enc.data.enemy.actions_per_round if enc.data.enemy else 0
	_clear(_enemy_pips)
	for i in total_actions:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(16, 16)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var left := i < enc.enemy_actions_left
		pip.add_theme_stylebox_override("panel", Palette.box(Palette.CORAL if left else Color.TRANSPARENT,
			Palette.CORAL.darkened(0.2), 8, 2, 0))
		_enemy_pips.add_child(pip)
	_intent_bubble.modulate = Color.WHITE if enc.enemy_actions_left > 0 else Color(1, 1, 1, 0.4)
	_clear(_enemy_chips)
	for it in enc.enemy.items:
		var item: ItemInstance = it
		_enemy_chips.add_child(_chip(item.data.display_name, CardSets.color(item.data.card_set), false,
			func(): _show_popup(_item_view(item.data, false), "", [], "Enemy item")))

	# Market.
	_fill_shop()

	# Your trinkets / items.
	_clear(_trinkets_box)
	for i in me.trinkets.size():
		var t := me.trinkets[i]
		var idx := i
		var usable := enc.can_use_trinket(idx)
		var chip := _chip(t.get_name(), CardSets.color(t.data.card_set), usable, func(): _show_trinket_popup(idx))
		chip.modulate = Color.WHITE if usable else Color(0.7, 0.7, 0.7)
		chip.gui_input.connect(_on_trinket_chip_input.bind(chip, idx))
		_trinkets_box.add_child(chip)
	# The limit is always visible: MAX_TRINKETS frames, the free ones empty.
	for i in range(me.trinkets.size(), GameRules.MAX_TRINKETS):
		_trinkets_box.add_child(_empty_gear_slot(50.0))
	_clear(_items_box)
	for it in me.items:
		var item: ItemInstance = it
		_items_box.add_child(_chip(item.data.display_name, CardSets.color(item.data.card_set), false,
			func(): _show_popup(_item_view(item.data, false), "", [], "Passive — always on")))
	if me.items.is_empty():
		_items_box.add_child(_empty_gear_slot())

	# Hand (dimmed while the enemy acts).
	var views: Array[CardView] = []
	for c in me.hand:
		var v := _card_instance_view(c, CardView.HAND)
		v.payload = c
		if _choice and _choice.hand_only:
			# Picking in place: candidates stay bright, picked ones lift + glow.
			v.set_enabled(false)
			v.dim_when_disabled = not _choice.candidates.has(c)
			v.set_highlighted(_picked.has(c))
		elif pending_enh_slot >= 0:
			v.set_enabled(enc.can_buy_enhancement(pending_enh_slot, c))
			v.set_highlighted(true)
		else:
			v.set_enabled(enc.can_play(c))
			v.dim_when_disabled = false
		views.append(v)
	_hand.set_views(views)
	var picking_in_hand := _choice != null and _choice.hand_only
	_hand.modulate = Color.WHITE if my_turn or enc.is_over or picking_in_hand else Color(0.6, 0.62, 0.7)

	_hand.spawn_point = _pile.target_center()   # the pile moves when the window resizes
	_pile.set_counts(me.draw_pile.size(), me.discard.size())
	_pass_btn.disabled = not my_turn or pending_enh_slot >= 0
	_pass_btn.text = "Pass" if enc.round_num < enc.total_rounds() else "Finish"
	_table_hint.visible = pending_enh_slot >= 0 and _choice == null
	_update_choice_bar()


func _coin_pop(anchor: Control, before: int, now: int) -> void:
	if before < 0 or before == now or not anchor.is_inside_tree():
		return
	var d := now - before
	var col := "#ffd166" if d > 0 else "#ff7f6a"
	Fx.float_text(_fx_layer, anchor.get_global_rect().get_center() + Vector2(0, -6),
		"[color=%s]%+d[/color] 🪙" % [col, d], 30)


func _round_banner(text: String) -> void:
	var l := CardView._label(text, 64, Palette.TEAL)
	l.add_theme_color_override("font_outline_color", Palette.ABYSS)
	l.add_theme_constant_override("outline_size", 12)
	_fx_layer.add_child(l)
	l.reset_size()
	l.pivot_offset = l.size * 0.5
	l.global_position = _table_center() - l.size * 0.5
	l.modulate.a = 0.0
	l.scale = Vector2(0.7, 0.7)
	var tw := l.create_tween()
	tw.set_parallel().tween_property(l, "modulate:a", 1.0, 0.25)
	tw.tween_property(l, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.6)
	tw.chain().tween_property(l, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(l.queue_free)


func _empty_gear_slot(height := 44.0) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, height)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", Palette.box(Color.TRANSPARENT, Palette.MUTED.darkened(0.45), 22, 2, 0))
	var l := CardView._label("+", 26, Palette.MUTED.darkened(0.3))
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


# ================================================================ market

## The whole market, always on screen: cards on the top row, items /
## trinkets / upgrades on the bottom row. Tiles are sized to the space.
func _fill_shop() -> void:
	_clear(_shop_row)
	_shop_cards_row = null
	var shop := enc.shop
	var gear_n := shop.items.size() + shop.trinkets.size() + shop.enhancements.size()
	var gear_groups := int(shop.items.size() > 0) + int(shop.trinkets.size() > 0) + int(shop.enhancements.size() > 0)

	# Space available inside the market panel.
	var vp := get_viewport_rect().size
	var avail_w := vp.x - 290.0 - 12.0 * 3 - 24.0 - 20.0
	var avail_h := vp.y - 24.0 - (CardView.HAND.y + 30.0) - 10.0 - 20.0 - 2 * 18.0 - 10.0
	var card_h := avail_h * (0.58 if gear_n > 0 else 1.0)
	var gear_h := avail_h - card_h
	var n_cards := maxi(1, shop.cards.size())
	var card_w := minf(card_h * CardView.SMALL.x / CardView.SMALL.y, (avail_w - 10.0 * n_cards) / n_cards)
	var card_tile := Vector2(card_w, card_w * CardView.SMALL.y / CardView.SMALL.x)
	var gear_w := minf(gear_h * 1.4, (avail_w - 10.0 * gear_n - GROUP_GAP * 2 * maxi(0, gear_groups - 1)) / maxi(1, gear_n))
	var gear_tile := Vector2(gear_w, gear_h)

	var cards_line := _market_line()
	var gear_line := _market_line() if gear_n > 0 else null

	if shop.cards.size() > 0:
		var row := _market_group(cards_line, "CARDS", Palette.TEAL)
		_shop_cards_row = row
		for slot in shop.cards.size():
			var cd: CardData = shop.cards[slot]
			if cd == null:
				row.add_child(_empty_slot(card_tile)); continue
			var s := slot
			var v := _card_data_view(cd, card_tile)
			v.set_enabled(enc.can_buy_card(s))
			var make := func(): return _card_data_view(cd, card_tile)
			_attach_buy_drag(v, func(): return enc.buy_card(s), _pile, make)
			v.tapped.connect(func(): _show_popup(_card_data_view(cd, CardView.LARGE), cd.flavor_text, [
				{"label": "%d" % enc.card_price(enc.player, cd.cost), "icon": "🛍", "enabled": enc.can_buy_card(s),
					"cb": func(): _buy_with_fx(func(): return enc.buy_card(s), make.call(), _pile)}]))
			row.add_child(v)

	if shop.items.size() > 0:
		var row := _market_group(gear_line, "ITEMS", Palette.KELP)
		for slot in shop.items.size():
			var it: ItemData = shop.items[slot]
			if it == null:
				row.add_child(_empty_slot(gear_tile)); continue
			var s := slot
			var v := _item_view(it, true, gear_tile)
			v.set_enabled(enc.can_buy_item(s))
			var make := func(): return _item_view(it, true, gear_tile)
			_attach_buy_drag(v, func(): return enc.buy_item(s), _items_panel, make)
			v.tapped.connect(func(): _show_popup(_item_view(it, true, CardView.LARGE), "", [
				{"label": "%d" % enc.item_price(it), "icon": "🛍", "enabled": enc.can_buy_item(s),
					"cb": func(): _buy_with_fx(func(): return enc.buy_item(s), make.call(), _items_panel)}]))
			row.add_child(v)

	if shop.trinkets.size() > 0:
		var row := _market_group(gear_line, "TRINKETS", Palette.GOLD)
		for slot in shop.trinkets.size():
			var td: TrinketData = shop.trinkets[slot]
			if td == null:
				row.add_child(_empty_slot(gear_tile)); continue
			var s := slot
			var v := _shop_trinket_view(td, gear_tile)
			v.set_enabled(enc.can_buy_trinket(s))
			var make := func(): return _shop_trinket_view(td, gear_tile)
			_attach_buy_drag(v, func(): return enc.buy_trinket(s), _trinkets_panel, make)
			v.tapped.connect(func(): _show_popup(_shop_trinket_view(td, CardView.LARGE), "", [
				{"label": "%d" % enc.trinket_buy_cost(td), "icon": "🛍", "enabled": enc.can_buy_trinket(s),
					"cb": func(): _buy_with_fx(func(): return enc.buy_trinket(s), make.call(), _trinkets_panel)}]))
			row.add_child(v)

	if shop.enhancements.size() > 0:
		var row := _market_group(gear_line, "UPGRADES", Palette.CARD_ENH.lightened(0.4))
		for slot in shop.enhancements.size():
			var ed: EnhancementData = shop.enhancements[slot]
			if ed == null:
				row.add_child(_empty_slot(gear_tile)); continue
			var s := slot
			var tint := CardSets.color(ed.card_set).lerp(Palette.CARD_ENH, 0.5)
			var e_price := enc.enhancement_price(ed)
			var v := CardView.make(ed.display_name, e_price, ed.get_description(), tint, gear_tile, "", "", "", ed.cost, ed.icon)
			v.set_enabled(enc.can_buy_enhancement(s))
			v.tapped.connect(func(): _show_popup(
				CardView.make(ed.display_name, e_price, ed.get_description(), tint, CardView.LARGE, "UPGRADE", "", "", ed.cost, ed.icon), ed.description, [
				{"label": "Choose card (%d)" % e_price, "enabled": enc.can_buy_enhancement(s),
					"cb": func(): pending_enh_slot = s; _refresh()}]))
			row.add_child(v)


## One horizontal line of market groups.
func _market_line() -> HBoxContainer:
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", GROUP_GAP * 2)
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_row.add_child(line)
	return line


const GROUP_GAP := 14


## A labelled group in the market; returns the row to put tiles in.
func _market_group(line: HBoxContainer, title: String, color: Color) -> HBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	var l := CardView._label(title, 12, color)
	vb.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	line.add_child(vb)
	return row


func _count(arr: Array) -> int:
	var n := 0
	for x in arr:
		if x != null:
			n += 1
	return n


## Buy from a popup button: the bought thing flies from the centre to `target`.
func _buy_with_fx(buy: Callable, ghost: CardView, target: DropTarget) -> void:
	if not buy.call():
		ghost.free()
		return
	_add_fx(ghost, get_viewport_rect().size * 0.5)
	_fly_to_target(ghost, target)


func _fly_to_target(ghost: Control, target: DropTarget) -> void:
	var to := _pile.target_center() if target == _pile else target.get_global_rect().get_center()
	Fx.fly_into(ghost, to, func():
		if target == _pile:
			_pile.pulse()
		else:
			var tw := target.create_tween()
			tw.tween_property(target, "self_modulate", Color(1.6, 1.5, 1.1), 0.1)
			tw.tween_property(target, "self_modulate", Color.WHITE, 0.25))


## Market tiles: drag onto `target` (deck / items / trinkets) and release to buy.
func _attach_buy_drag(v: CardView, buy: Callable, target: DropTarget, make_ghost: Callable) -> void:
	v.gui_input.connect(func(e: InputEvent): _on_shop_tile_input(e, v, buy, target, make_ghost))


func _on_shop_tile_input(e: InputEvent, v: CardView, buy: Callable, target: DropTarget, make_ghost: Callable) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_shop_drag = {"view": v, "press": e.global_position, "ghost": null, "offset": Vector2.ZERO, "hover": false}
		elif _shop_drag.get("view") == v:
			var ghost: CardView = _shop_drag["ghost"]
			var hover: bool = _shop_drag["hover"]
			var home: Vector2 = v.get_global_rect().get_center()
			_shop_drag = {}
			if ghost == null:
				return
			target.set_state(DropTarget.State.IDLE)
			v.modulate.a = 1.0
			if not hover:
				_return_ghost(ghost, home)
				return
			# Buying rebuilds the market (freeing `v`), so defer it.
			(func():
				if buy.call():
					_fly_to_target(ghost, target)
				else:
					_return_ghost(ghost, home)).call_deferred()
	elif e is InputEventMouseMotion and _shop_drag.get("view") == v:
		if _shop_drag["ghost"] == null and v.enabled and e.global_position.distance_to(_shop_drag["press"]) > HandView.DRAG_START:
			v._pressed = false   # cancel the tap
			var ghost: CardView = make_ghost.call()
			ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_fx_layer.add_child(ghost)
			ghost.size = v.size
			ghost.pivot_offset = ghost.size * 0.5
			ghost.scale = Vector2(1.08, 1.08)
			_shop_drag["ghost"] = ghost
			_shop_drag["offset"] = v.global_position - e.global_position
			v.modulate.a = 0.3
			target.set_state(DropTarget.State.ACTIVE)
		var g: CardView = _shop_drag["ghost"]
		if g:
			g.global_position = e.global_position + _shop_drag["offset"]
			var hover := target.contains_global(e.global_position)
			if hover != _shop_drag["hover"]:
				_shop_drag["hover"] = hover
				target.set_state(DropTarget.State.HOVER if hover else DropTarget.State.ACTIVE)
				g.set_highlighted(hover)


func _return_ghost(ghost: Control, home_global: Vector2) -> void:
	var tw := ghost.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "global_position", home_global - ghost.size * 0.5, 0.2)
	tw.tween_property(ghost, "scale", Vector2.ONE, 0.2)
	tw.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(ghost.queue_free)


# ============================================================ deck viewer

func _show_deck_viewer() -> void:
	if enc == null:
		return
	var me := enc.player
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vb)
	# The draw pile is shown sorted so it doesn't reveal the draw order.
	var draw_sorted := me.draw_pile.duplicate()
	draw_sorted.sort_custom(func(a, b): return a.get_name() < b.get_name())
	var sections := [["Deck", draw_sorted, "(not in draw order)"], ["Hand", me.hand, ""],
			["Discard", me.discard, ""]]
	if not me.removed.is_empty():
		sections.append(["Removed 🗑", me.removed, "(this encounter)"])
	if not me.destroyed.is_empty():
		sections.append(["Destroyed 🔥", me.destroyed, ""])
	for section in sections:
		var cards: Array = section[1]
		vb.add_child(Icons.rich_label("%s  (%d)  %s" % [section[0], cards.size(), section[2]], 20, Palette.KELP))
		if cards.is_empty():
			vb.add_child(CardView._label("—", 16, Palette.MUTED))
			continue
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		vb.add_child(grid)
		for c in cards:
			var v := _card_instance_view(c, CardView.SMALL)
			v.dim_when_disabled = false
			v.set_enabled(false)
			grid.add_child(v)
	_show_popup(scroll, "", [], "All %d of your cards" % me.all_cards().size())


# ================================================================ choices

## Verb shown while picking, with its icon where the game has one.
const VERB_ICONS := {"Discard": "⤵", "Destroy": "🔥", "Remove": "🗑", "Refresh": "↺", "Retain": "📌", "Draw": "🂠", "Buy": "🛍"}


func _verb(req: ChoiceRequest) -> String:
	var icon: String = VERB_ICONS.get(req.verb, "")
	return req.verb + (" " + icon if icon != "" else "")


func _on_choice_requested(req: ChoiceRequest) -> void:
	_choice = req
	_picked = []
	_hand.clear_lifted()
	pending_enh_slot = -1
	if req.kind == ChoiceRequest.Kind.CARDS and req.hand_only:
		_close_popup()
		_refresh()
	else:
		_show_picker()


func _needs_confirm() -> bool:
	return not (_choice.min_count == 1 and _choice.max_count == 1)


func _toggle_pick(item: Variant) -> void:
	if _choice == null or not _choice.candidates.has(item):
		return
	if _picked.has(item):
		_picked.erase(item)
	elif _picked.size() < _choice.max_count:
		_picked.append(item)
	elif _choice.max_count == 1:
		_picked = [item]
	else:
		return
	if not _needs_confirm() and _picked.size() == 1:
		_submit_choice()
		return
	if _choice.hand_only:
		for c in _choice.candidates:
			_hand.set_lifted(c, _picked.has(c))
	_update_choice_bar()
	_update_picker()


func _submit_choice() -> void:
	if _choice == null:
		return
	var picks := _picked.duplicate()
	var hand_only := _choice.hand_only
	if picks.size() < _choice.min_count or picks.size() > _choice.max_count:
		return
	_choice = null
	_picked = []
	_hand.clear_lifted()
	if not hand_only:
		_close_popup(true)
	enc.submit_choice(picks)
	_refresh()


## The bar above the hand while picking cards in place: what to do + Confirm.
func _update_choice_bar() -> void:
	var in_hand := _choice != null and _choice.hand_only
	_choice_bar.visible = in_hand
	if not in_hand:
		return
	_choice_label.clear()
	var count := "%d" % _choice.max_count if _choice.min_count == _choice.max_count else \
		("up to %d" % _choice.max_count if _choice.min_count == 0 else "%d-%d" % [_choice.min_count, _choice.max_count])
	Icons.append(_choice_label, "[b]%s %s[/b]   %d/%d" % [_verb(_choice), count, _picked.size(), _choice.max_count], 24)
	_choice_ok.visible = _needs_confirm()
	_choice_ok.disabled = _picked.size() < _choice.min_count
	_choice_ok.text = "Confirm" if not _picked.is_empty() or _choice.min_count > 0 else "Skip"


## Modal picker for choices that aren't just "cards in your hand".
func _show_picker() -> void:
	var req := _choice
	_close_popup(true)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.03, 0.07, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_layer.add_child(center)
	var vp := get_viewport_rect().size
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	center.add_child(outer)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	outer.add_child(head)
	if req.source_card:
		var src := _card_instance_view(req.source_card, CardView.SMALL)
		src.hoverable = false
		src.dim_when_disabled = false
		src.set_enabled(false)
		head.add_child(src)
	var title_text := "[b]%s[/b]" % _verb(req)
	if req.source_card == null and req.source_name != "":
		title_text = "[color=#9fc3cf][font_size=20]%s[/font_size][/color]\n" % req.source_name + title_text
	var title := Icons.rich_label(title_text, 30, Palette.GOLD)
	title.custom_minimum_size.x = 260
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(minf(vp.x - 80.0, 820.0), clampf(vp.y - 340.0, 200.0, 420.0))
	outer.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)

	_picker_views = {}
	_picker_ok = null
	if req.kind == ChoiceRequest.Kind.OPTIONS:
		scroll.custom_minimum_size.y = minf(scroll.custom_minimum_size.y, 110.0 * req.candidates.size())
		for i in req.candidates.size():
			var ok: bool = req.enabled.is_empty() or req.enabled[i]
			var idx := i
			body.add_child(_option_tile(req.candidates[i], ok, func(): _picked = [idx]; _submit_choice()))
	else:
		var groups := {}
		var order: Array = []
		for i in req.candidates.size():
			var g: String = req.groups[i] if i < req.groups.size() else ""
			if not groups.has(g):
				groups[g] = []
				order.append(g)
			groups[g].append(req.candidates[i])
		for g in order:
			var items: Array = groups[g]
			if g == "Deck" and not req.ordered:
				items = items.duplicate()
				items.sort_custom(func(a, b): return a.get_name() < b.get_name())
			if g != "" and order.size() > 1 or g == "Top":
				body.add_child(CardView._label(g, 18, Palette.KELP))
			var grid := GridContainer.new()
			grid.columns = maxi(1, int((scroll.custom_minimum_size.x - 10.0) / (CardView.SMALL.x + 8.0)))
			grid.add_theme_constant_override("h_separation", 8)
			grid.add_theme_constant_override("v_separation", 8)
			body.add_child(grid)
			for item in items:
				var v := _picker_view(req, item)
				v.dim_when_disabled = false
				v.hover_grow = false
				_picker_views[item] = v
				v.tapped.connect(_toggle_pick.bind(item))
				grid.add_child(v)

	if req.kind != ChoiceRequest.Kind.OPTIONS and _needs_confirm():
		_picker_ok = _big_button("Confirm", Palette.TEAL)
		_picker_ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_picker_ok.pressed.connect(_submit_choice)
		outer.add_child(_picker_ok)
	_update_picker()


## Selection glow + Confirm state in the picker popup.
func _update_picker() -> void:
	for k in _picker_views:
		if is_instance_valid(_picker_views[k]):
			_picker_views[k].set_highlighted(_picked.has(k))
	if _picker_ok and is_instance_valid(_picker_ok) and _choice:
		_picker_ok.disabled = _picked.size() < _choice.min_count
		_picker_ok.text = "Skip" if _picked.is_empty() and _choice.min_count == 0 else "Confirm  %d/%d" % [_picked.size(), _choice.max_count]


## A wide tappable tile for "X OR Y" options.
func _option_tile(text: String, enabled: bool, cb: Callable) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 92)
	p.add_theme_stylebox_override("panel", Palette.box(Palette.PANEL if enabled else Palette.DEEP,
		Palette.TEAL if enabled else Palette.MUTED.darkened(0.5), 14, 2, 16))
	p.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	var l := Icons.rich_label(text, 28, Palette.FOAM if enabled else Palette.MUTED.darkened(0.3))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(l)
	if enabled:
		p.mouse_entered.connect(func(): p.add_theme_stylebox_override("panel", Palette.box(Palette.PANEL.lightened(0.08), Palette.GOLD, 14, 3, 16)))
		p.mouse_exited.connect(func(): p.add_theme_stylebox_override("panel", Palette.box(Palette.PANEL, Palette.TEAL, 14, 2, 16)))
		p.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed: cb.call())
	return p


func _picker_view(req: ChoiceRequest, item: Variant) -> CardView:
	match req.kind:
		ChoiceRequest.Kind.SHOP_CARD:
			return _card_data_view(enc.shop.cards[item], CardView.SMALL)
		ChoiceRequest.Kind.SHOP_TRINKET:
			return _trinket_data_view(enc.shop.trinkets[item], CardView.SMALL)
		ChoiceRequest.Kind.TRINKET:
			var t: TrinketInstance = enc.player.trinkets[item]
			if req.trinket_level > 0 and not t.data.levels.is_empty():
				var lv := mini(req.trinket_level, t.data.levels.size())
				return CardView.make("%s (Lv %d)" % [t.data.display_name, lv], -1, t.data.levels[lv - 1].get_text(),
					CardSets.color(t.data.card_set), CardView.SMALL)
			return CardView.make(t.get_name(), -1, t.get_text(), CardSets.color(t.data.card_set), CardView.SMALL)
	return _card_instance_view(item, CardView.SMALL)


# ================================================================= views

func _card_data_view(cd: CardData, sz: Vector2) -> CardView:
	var v := _card_data_view_raw(cd, sz)
	var vars := _card_vars(cd)
	_attach_hover(v, cd.get_play_text(vars) + " " + cd.get_buy_text(vars), _mentioned(cd))
	return v


func _card_data_view_raw(cd: CardData, sz: Vector2) -> CardView:
	var price := enc.card_price(enc.player, cd.cost) if enc else cd.cost
	var vars := _card_vars(cd)
	return CardView.make(cd.display_name, price, cd.get_play_text(vars), CardSets.color(cd.card_set), sz,
		"⚡" if cd.instant and not cd.has_custom_text() else "", "", cd.get_buy_text(vars), cd.cost)


func _card_instance_view(c: CardInstance, sz: Vector2) -> CardView:
	var v := _card_instance_view_raw(c, sz)
	var vars := _card_vars(c.data, c)
	_attach_hover(v, c.play_text(vars) + " " + c.buy_text(vars), _mentioned(c.data), c.enhancements)
	return v


func _card_instance_view_raw(c: CardInstance, sz: Vector2) -> CardView:
	# Enhancements show as corner badges; they never change the card's text.
	var vars := _card_vars(c.data, c)
	return CardView.make(c.get_name(), c.get_cost(), c.play_text(vars), CardSets.color(c.data.card_set), sz,
		"⚡" if c.is_instant() and not c.data.has_custom_text() else "", "", c.buy_text(vars), -1,
		c.enhancements.map(func(e: EnhancementData): return e.icon))


## Text values for one card, including its own {gain}.
func _card_vars(cd: CardData, c: CardInstance = null) -> Dictionary:
	return enc.card_text_vars(cd, c) if enc else {}


func _item_view(it: ItemData, show_cost: bool, sz: Vector2 = CardView.SMALL) -> CardView:
	var price := (enc.item_price(it) if enc else it.cost) if show_cost else -1
	var v := CardView.make(it.display_name, price, it.get_description(), CardSets.color(it.card_set), sz,
		"ITEM" if sz == CardView.LARGE else "", "", "", it.cost if show_cost else -1)
	_attach_hover(v, it.get_description(), _mentioned_in(it.effects))
	return v


func _trinket_data_view(td: TrinketData, sz: Vector2) -> CardView:
	# (sz may be a shrunken market tile)
	var desc := td.levels[0].get_text() if not td.levels.is_empty() else ""
	if td.description != "":
		desc = td.description + "\n" + desc
	var v := CardView.make(td.display_name, enc.trinket_buy_cost(td) if enc else td.cost, desc, CardSets.color(td.card_set), sz,
		"TRINKET" if sz == CardView.LARGE else "", "", "", td.cost)
	var fx: Array = []
	for lv in td.levels:
		fx.append_array(lv.effects)
	_attach_hover(v, desc, _mentioned_in(fx))
	return v


## A market trinket. If you already own it, the tile shows the NEXT level
## (purple-tinted, with the upgrade price): buying it levels yours up.
func _shop_trinket_view(td: TrinketData, sz: Vector2) -> CardView:
	var owned := enc.owned_trinket(td)
	if owned == null or not owned.can_upgrade():
		return _trinket_data_view(td, sz)
	var next: TrinketLevel = td.levels[owned.level + 1]
	var desc := next.get_text()
	if td.description != "":
		desc = td.description + "\n" + desc
	return CardView.make("%s (Lv %d)" % [td.display_name, owned.level + 2], enc.trinket_buy_cost(td), desc,
		CardSets.color(td.card_set).lerp(Palette.CARD_ENH, 0.5), sz, "UPGRADE" if sz == CardView.LARGE else "", "", "",
		owned.upgrade_cost())


## Drag one of your trinkets onto the market to sell it (tap = inspect).
func _on_trinket_chip_input(e: InputEvent, chip: Button, idx: int) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_sell_drag = {"chip": chip, "press": e.global_position, "ghost": null, "hover": false}
		elif _sell_drag.get("chip") == chip:
			var ghost: CardView = _sell_drag["ghost"]
			var hover: bool = _sell_drag["hover"]
			_sell_drag = {}
			if ghost == null:
				return
			_shop_panel.set_state(DropTarget.State.IDLE)
			chip.modulate.a = 1.0
			# Selling rebuilds the trinket list (freeing `chip`), so defer it.
			(func():
				if hover and enc.sell_trinket(idx):
					Fx.fly_into(ghost, _shop_panel.get_global_rect().get_center(), Callable(), 0.3)
				else:
					_return_ghost(ghost, chip.get_global_rect().get_center() if is_instance_valid(chip) else ghost.global_position)).call_deferred()
	elif e is InputEventMouseMotion and _sell_drag.get("chip") == chip:
		if _sell_drag["ghost"] == null and enc.can_sell_trinket(idx) \
				and e.global_position.distance_to(_sell_drag["press"]) > HandView.DRAG_START:
			var t := enc.player.trinkets[idx]
			var ghost := CardView.make(t.get_name(), -1, "+%d 🪙" % t.sell_value(), CardSets.color(t.data.card_set),
				CardView.SMALL)
			ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ghost.hoverable = false
			_fx_layer.add_child(ghost)
			ghost.size = CardView.SMALL
			ghost.pivot_offset = ghost.size * 0.5
			ghost.scale = Vector2(1.08, 1.08)
			_sell_drag["ghost"] = ghost
			chip.modulate.a = 0.35
			_shop_panel.set_state(DropTarget.State.ACTIVE)
		var g: CardView = _sell_drag["ghost"]
		if g:
			g.global_position = e.global_position - g.size * 0.5
			var hover := _shop_panel.contains_global(e.global_position)
			if hover != _sell_drag["hover"]:
				_sell_drag["hover"] = hover
				_shop_panel.set_state(DropTarget.State.HOVER if hover else DropTarget.State.ACTIVE)
				g.set_highlighted(hover)


func _show_trinket_popup(idx: int) -> void:
	var t := enc.player.trinkets[idx]
	var actions := [{"label": "Use", "enabled": enc.can_use_trinket(idx), "cb": func(): enc.use_trinket(idx)}]
	_show_popup(CardView.make(t.get_name(), -1, t.get_description(), CardSets.color(t.data.card_set), CardView.LARGE,
		"TRINKET" + (" · used" if t.used else "")), "", actions,
		"")


func _show_intents_popup() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	var upcoming := enc.upcoming_intents(4)
	for i in upcoming.size():
		var intent: EnemyIntent = upcoming[i]
		var v := CardView.make(intent.display_name, -1, intent.get_description(), Palette.PANEL,
			Vector2(LARGE_W, 110), ("NEXT · " if i == 0 else "THEN · ") + EnemyIntent.kind_label(intent.kind))
		v.dim_when_disabled = false
		v.set_enabled(i == 0)
		vb.add_child(v)
	_show_popup(vb, "", [], "%s answers your actions in this order, %d times per round (%d left)." % [
		enc.enemy.display_name, enc.data.enemy.actions_per_round, enc.enemy_actions_left])




func _chip(text: String, color: Color, glow: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.clip_text = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_stylebox_override("normal", Palette.box(color, Palette.GOLD if glow else color.lightened(0.2), 26, 2 if glow else 1, 12))
	b.add_theme_stylebox_override("hover", Palette.box(color.lightened(0.1), Palette.GOLD if glow else color.lightened(0.3), 26, 2, 12))
	b.add_theme_stylebox_override("pressed", Palette.box(color.darkened(0.2), Palette.GOLD, 26, 2, 12))
	b.pressed.connect(cb)
	return b


func _empty_slot(sz: Vector2 = CardView.SMALL) -> Control:
	var v := CardView.make("", -1, "", Palette.DEEP, sz)
	v.set_enabled(false)
	return v


func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


# ============================================================ hover legend

## Hovering a tile shows what its icons mean, plus any cards it mentions.
## `enhs`: the card's enhancements (one legend row each).
func _attach_hover(v: CardView, text: String, cards: Array, enhs: Array = []) -> void:
	var icons := Icons.icons_in(text)
	for enh in enhs:
		for ic in Icons.icons_in(enh.get_description()):
			if not icons.has(ic):
				icons.append(ic)
	if icons.is_empty() and cards.is_empty() and enhs.is_empty():
		return
	v.hover_changed.connect(func(on: bool):
		if on:
			_show_legend(v, icons, cards, enhs)
		elif _hover_owner == v:
			_hide_legend())
	v.tree_exiting.connect(func():
		if _hover_owner == v:
			_hide_legend())


func _hide_legend() -> void:
	_hover_owner = null
	if _hover_layer:
		for c in _hover_layer.get_children():
			c.queue_free()


func _show_legend(v: CardView, icons: Array, cards: Array, enhs: Array = []) -> void:
	_hide_legend()
	_hover_owner = v
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", Palette.box(Palette.DEEP, Palette.TEAL, 12, 2, 10))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vb)
	# One row per enhancement; repeats are shown once with a count.
	var counts := {}
	for enh in enhs:
		counts[enh] = counts.get(enh, 0) + 1
	for enh in counts:
		var times: String = "  ×%d" % counts[enh] if counts[enh] > 1 else ""
		var erow := Icons.rich_label("%s  [b]%s[/b]%s: %s" % [enh.icon, enh.display_name, times, enh.get_description()], 16, Palette.FOAM)
		erow.autowrap_mode = TextServer.AUTOWRAP_OFF
		vb.add_child(erow)
	for ic in icons:
		var row := Icons.rich_label("%s  %s" % [ic, Icons.TIPS[ic]], 16, Palette.FOAM)
		row.autowrap_mode = TextServer.AUTOWRAP_OFF
		vb.add_child(row)
	if not cards.is_empty():
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(hb)
		for cd in cards:
			var m := _card_data_view_raw(cd, CardView.SMALL)
			m.hoverable = false
			m.dim_when_disabled = false
			m.set_enabled(true)
			m.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(m)
	_hover_layer.add_child(panel)
	panel.reset_size()
	var vp := get_viewport_rect().size
	var r := v.get_global_rect()
	var pos := Vector2(r.end.x + 10.0, r.position.y)
	if pos.x + panel.size.x > vp.x:
		pos.x = r.position.x - panel.size.x - 10.0
	pos.x = clampf(pos.x, 4.0, maxf(4.0, vp.x - panel.size.x - 4.0))
	pos.y = clampf(pos.y, 4.0, maxf(4.0, vp.y - panel.size.y - 4.0))
	panel.global_position = pos


## Cards that `cd`'s effects create or transform into (shown when hovering it).
func _mentioned(cd: CardData) -> Array:
	var fx: Array = []
	for arr in [cd.on_play, cd.on_buy, cd.on_discard, cd.on_destroy, cd.on_turn_end_in_hand]:
		fx.append_array(arr)
	return _mentioned_in(fx, cd)


func _mentioned_in(effects: Array, exclude: CardData = null) -> Array:
	var out: Array = []
	_collect_cards(effects, out, exclude, 0)
	return out


func _collect_cards(list: Array, out: Array, exclude: CardData, depth: int) -> void:
	if depth > 4:
		return
	for e in list:
		if e == null:
			continue
		if e is CardData:
			if e != exclude and not out.has(e):
				out.append(e)
			continue
		if not (e is Resource):
			continue
		for prop in (e as Resource).get_property_list():
			if not (prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var val: Variant = e.get(prop["name"])
			if val is CardData:
				_collect_cards([val], out, exclude, depth + 1)
			elif val is Array:
				_collect_cards(val, out, exclude, depth + 1)
			elif val is Resource and (val is Effect or val is EffectOption):
				_collect_cards([val], out, exclude, depth + 1)


# ================================================================ popups

## Generic modal: dims the screen, shows `content` plus action buttons.
## Tap outside to close.
func _show_popup(content: Control, subtitle: String, actions: Array, note := "") -> void:
	if _choice and not _choice.hand_only:
		return   # the picker stays until answered
	_close_popup()
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.03, 0.07, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed: _close_popup(false))
	_popup_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_layer.add_child(center)
	# Landscape: content on the left, text + buttons stacked on the right.
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 28)
	center.add_child(hb)
	if content is CardView:
		(content as CardView).dim_when_disabled = false
		(content as CardView).hoverable = false
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(content)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.custom_minimum_size.x = 280
	hb.add_child(vb)
	if subtitle != "":
		var s := CardView._label(subtitle, 18, Palette.MUTED)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.custom_minimum_size.x = 280
		vb.add_child(s)
	if note != "":
		var n := CardView._label(note, 17, Palette.KELP)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.custom_minimum_size.x = 280
		vb.add_child(n)
	for a in actions:
		var b := _big_button(a["label"], Palette.TEAL)
		b.disabled = not a["enabled"]
		var cb: Callable = a["cb"]
		b.pressed.connect(func(): _close_popup(); cb.call())
		vb.add_child(b)
	var close := _big_button("Close", Palette.PANEL)
	close.pressed.connect(func(): _close_popup())
	vb.add_child(close)


func _close_popup(force := false) -> void:
	if _choice and not _choice.hand_only and not force:
		return
	for c in _popup_layer.get_children():
		c.queue_free()


func _show_log() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.box(Palette.DEEP, Palette.TEAL.darkened(0.3), 16, 2, 16))
	panel.custom_minimum_size = Vector2(760, 640)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var title := CardView._label("Log", 26, Palette.TEAL)
	vb.add_child(title)
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.scroll_following = true
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", 18)
	r.add_theme_font_size_override("bold_font_size", 18)
	r.text = _log_text
	vb.add_child(r)
	_show_popup(panel, "", [])


func _show_end_overlay(won: bool) -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", Palette.box(Palette.PANEL, Palette.GOLD if won else Palette.CORAL, 20, 4, 36))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	box.add_child(vb)
	var h := CardView._label("Victory!" if won else "Sunk.", 56, Palette.GOLD if won else Palette.CORAL)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(h)
	var d := CardView._label("You finished with %d / %d coins." % [enc.player.coins, enc.coin_target()]
		+ ("\nReward: %d gold" % enc.data.gold_reward if won else ""), 24, Palette.FOAM)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(d)
	await get_tree().create_timer(0.4).timeout
	_show_popup(box, "", [{"label": "Play again", "enabled": true, "cb": func(): get_tree().reload_current_scene()}])



func _big_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(170, 76)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_stylebox_override("normal", Palette.box(color.darkened(0.35), color, 14, 2, 12))
	b.add_theme_stylebox_override("hover", Palette.box(color.darkened(0.2), color.lightened(0.3), 14, 2, 12))
	b.add_theme_stylebox_override("pressed", Palette.box(color.darkened(0.55), color, 14, 2, 12))
	b.add_theme_stylebox_override("disabled", Palette.box(Palette.DEEP, Palette.PANEL, 14, 2, 12))
	b.add_theme_color_override("font_disabled_color", Palette.MUTED.darkened(0.3))
	return b


# ================================================================= build

func _build_ui() -> void:
	var th := Theme.new()
	th.default_font_size = 20
	th.set_color("font_color", "Label", Palette.FOAM)
	for state in ["normal", "hover", "pressed", "disabled"]:
		th.set_stylebox(state, "Button", Palette.box(Palette.PANEL, Palette.TEAL.darkened(0.3), 12, 1, 10))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme = th

	var bg := ColorRect.new()
	bg.color = Palette.ABYSS
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	_margin = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	margin.add_child(main)

	# ================= LEFT COLUMN: status, enemy, your trinkets & items
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 290
	left.add_theme_constant_override("separation", 10)
	main.add_child(left)

	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 10)
	left.add_child(status)
	_round_label = CardView._label("Round", 19, Palette.MUTED)
	_round_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_child(_round_label)
	var coin_box := VBoxContainer.new()
	coin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coin_box.add_theme_constant_override("separation", 2)
	status.add_child(coin_box)
	_coins_label = CardView._label("0 / 0", 28, Palette.GOLD)
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_box.add_child(_coins_label)
	_coins_bar = ProgressBar.new()
	_coins_bar.show_percentage = false
	_coins_bar.custom_minimum_size.y = 10
	_coins_bar.add_theme_stylebox_override("background", Palette.box(Palette.DEEP, Color.TRANSPARENT, 5, 0, 0))
	_coins_bar.add_theme_stylebox_override("fill", Palette.box(Palette.GOLD, Color.TRANSPARENT, 5, 0, 0))
	coin_box.add_child(_coins_bar)

	# Enemy card.
	var enemy_panel := PanelContainer.new()
	enemy_panel.add_theme_stylebox_override("panel", Palette.box(Palette.PANEL, Palette.CORAL.darkened(0.5), 16, 2, 12))
	left.add_child(enemy_panel)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 10)
	enemy_panel.add_child(ev)
	var eh := HBoxContainer.new()
	eh.add_theme_constant_override("separation", 12)
	ev.add_child(eh)
	_enemy_portrait = PanelContainer.new()
	_enemy_portrait.custom_minimum_size = Vector2(70, 70)
	eh.add_child(_enemy_portrait)
	_enemy_portrait_label = CardView._label("?", 34, Palette.FOAM)
	_enemy_portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_enemy_portrait.add_child(_enemy_portrait_label)
	var einfo := VBoxContainer.new()
	einfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	einfo.alignment = BoxContainer.ALIGNMENT_CENTER
	eh.add_child(einfo)
	_enemy_name = CardView._label("Enemy", 22, Palette.FOAM)
	_enemy_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	einfo.add_child(_enemy_name)
	_enemy_sub = Icons.rich_label("", 16, Palette.MUTED)
	einfo.add_child(_enemy_sub)
	_enemy_pips = HBoxContainer.new()
	_enemy_pips.add_theme_constant_override("separation", 5)
	_enemy_pips.tooltip_text = "Enemy actions left this round"
	einfo.add_child(_enemy_pips)
	_intent_bubble = PanelContainer.new()
	_intent_bubble.add_theme_stylebox_override("panel", Palette.box(Palette.CORAL.darkened(0.55), Palette.CORAL, 14, 3, 10))
	_intent_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	_intent_bubble.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT and enc: _show_intents_popup())
	ev.add_child(_intent_bubble)
	var ib := VBoxContainer.new()
	ib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ib.add_theme_constant_override("separation", 0)
	_intent_bubble.add_child(ib)
	_intent_kind = CardView._label("NEXT", 13, Palette.CORAL)
	ib.add_child(_intent_kind)
	_intent_title = CardView._label("", 24, Palette.FOAM)
	ib.add_child(_intent_title)
	# A red X over the intent while a cancel is pending (see _refresh). Drawn,
	# not a glyph, so it shows on web builds without symbol fonts.
	_intent_cross = Control.new()
	_intent_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intent_cross.visible = false
	_intent_cross.draw.connect(func():
		var r := Rect2(Vector2.ZERO, _intent_cross.size).grow(-6)
		_intent_cross.draw_line(r.position, r.end, Palette.CORAL, 5.0, true)
		_intent_cross.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Palette.CORAL, 5.0, true))
	_intent_cross.resized.connect(_intent_cross.queue_redraw)
	_intent_desc = Icons.rich_label("", 17, Palette.FOAM.darkened(0.1))
	ib.add_child(_intent_desc)
	_intent_bubble.add_child(_intent_cross)
	_enemy_chips = HBoxContainer.new()
	_enemy_chips.add_theme_constant_override("separation", 6)
	ev.add_child(_enemy_chips)

	# Your trinkets and items: also the drop targets for buying them.
	var gear := HBoxContainer.new()
	gear.add_theme_constant_override("separation", 8)
	gear.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(gear)
	_trinkets_panel = _gear_panel("TRINKETS", Palette.GOLD)
	_trinkets_box = _trinkets_panel.get_meta("box")
	gear.add_child(_trinkets_panel)
	_items_panel = _gear_panel("ITEMS", Palette.KELP)
	_items_box = _items_panel.get_meta("box")
	gear.add_child(_items_panel)

	var left_bottom := HBoxContainer.new()
	left_bottom.add_theme_constant_override("separation", 8)
	left.add_child(left_bottom)
	var buttons := [["Log", _show_log], ["Fullscreen", _toggle_fullscreen]]
	if OS.has_feature("web"):
		buttons.append(["Install", _install_app])   # shown once the browser offers it
	else:   # browsers can't close the tab from the game
		buttons.append(["Exit", _confirm_exit])
	for pair in buttons:
		var b := _big_button(pair[0], Palette.PANEL)
		b.custom_minimum_size = Vector2(0, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.x = 0
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(pair[1])
		left_bottom.add_child(b)
		if pair[0] == "Fullscreen":
			_fs_button = b
		if pair[0] == "Install":
			_install_button = b
			b.visible = false
			var t := Timer.new()
			t.wait_time = 1.5
			t.autostart = true
			t.timeout.connect(_update_install_button)
			add_child(t)

	# ================= RIGHT: market, table, hand
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	main.add_child(right)

	_shop_panel = DropTarget.new()
	_shop_panel.bg_color = Palette.DEEP
	_shop_panel.accent = Palette.TEAL
	_shop_panel.radius = 16
	_shop_panel.hover_scale = 1.0
	_shop_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_shop_panel)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 12)
	_shop_panel.add_child(sh)
	_shop_row = VBoxContainer.new()
	_shop_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_shop_row.add_theme_constant_override("separation", 10)
	sh.add_child(_shop_row)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	right.add_child(bottom)
	_hand = HandView.new()
	_hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand.custom_minimum_size.y = CardView.HAND.y + 30
	_hand.card_dropped.connect(_on_card_dropped)
	_hand.card_tapped.connect(_on_hand_tapped)
	bottom.add_child(_hand)
	_pile = PileView.new()
	_pile.size_flags_vertical = Control.SIZE_SHRINK_END
	_pile.tapped.connect(_show_deck_viewer)
	bottom.add_child(_pile)
	_pass_btn = _big_button("Pass", Palette.CORAL)
	_pass_btn.custom_minimum_size = Vector2(130, 90)
	_pass_btn.size_flags_vertical = Control.SIZE_SHRINK_END
	_pass_btn.pressed.connect(func(): enc.pass_turn())
	bottom.add_child(_pass_btn)

	_fx_layer = Control.new()
	_fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.z_index = 400   # above the fanned hand
	add_child(_fx_layer)

	# Upgrade picker hint (tap to cancel), floating above the hand.
	_table_hint = _big_button("Tap a card to upgrade  ·  cancel", Palette.CARD_ENH.lightened(0.3))
	_table_hint.custom_minimum_size = Vector2(0, 52)
	_table_hint.add_theme_font_size_override("font_size", 18)
	_table_hint.visible = false
	_table_hint.pressed.connect(func(): pending_enh_slot = -1; _refresh())
	_fx_layer.add_child(_table_hint)
	_table_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_table_hint.position.y -= 260

	# Picking cards in your hand: what to pick + Confirm, floating above the hand.
	_choice_bar = PanelContainer.new()
	_choice_bar.add_theme_stylebox_override("panel", Palette.box(Palette.PANEL, Palette.GOLD, 16, 3, 12))
	_choice_bar.visible = false
	var cb := HBoxContainer.new()
	cb.add_theme_constant_override("separation", 16)
	_choice_bar.add_child(cb)
	_choice_label = Icons.rich_label("", 24, Palette.FOAM)
	_choice_label.fit_content = true
	_choice_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_choice_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cb.add_child(_choice_label)
	_choice_ok = _big_button("Confirm", Palette.TEAL)
	_choice_ok.custom_minimum_size = Vector2(150, 56)
	_choice_ok.pressed.connect(_submit_choice)
	cb.add_child(_choice_ok)
	_fx_layer.add_child(_choice_bar)
	_choice_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_choice_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_choice_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_choice_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choice_bar.position.y -= 270

	_hover_layer = Control.new()
	_hover_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hover_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_layer.z_index = 450
	add_child(_hover_layer)

	_popup_layer = Control.new()
	_popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_layer.z_index = 500
	add_child(_popup_layer)

	# Shown when a phone is held upright.
	_rotate_overlay = ColorRect.new()
	(_rotate_overlay as ColorRect).color = Palette.ABYSS
	_rotate_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rotate_overlay.z_index = 1000
	_rotate_overlay.visible = false
	add_child(_rotate_overlay)
	var rc := CenterContainer.new()
	rc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rotate_overlay.add_child(rc)
	var rl := CardView._label("Please rotate your device\nto landscape", 40, Palette.TEAL)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rc.add_child(rl)
	get_viewport().size_changed.connect(_check_orientation)
	_check_orientation()


func _gear_panel(title: String, accent: Color) -> DropTarget:
	var p := DropTarget.new()
	p.bg_color = Palette.DEEP
	p.accent = accent
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	p.add_child(vb)
	vb.add_child(CardView._label(title, 13, accent))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	vb.add_child(box)
	p.set_meta("box", box)
	return p


## Where played cards pop and banners appear: just above the hand.
func _table_center() -> Vector2:
	var h := _hand.get_global_rect()
	return Vector2(h.get_center().x, h.position.y - 110.0)


## Web: install as an app (Chrome "Add to Home screen" / desktop install).
## The page stashes the browser's install prompt in window.__csInstall.
func _update_install_button() -> void:
	if _install_button and OS.has_feature("web"):
		_install_button.visible = bool(JavaScriptBridge.eval("!!window.__csInstall", true))


func _install_app() -> void:
	JavaScriptBridge.eval("if (window.__csInstall) { window.__csInstall.prompt(); window.__csInstall.userChoice.then(function(){ window.__csInstall = null; }); }", true)
	_install_button.visible = false


func _confirm_exit() -> void:
	var l := CardView._label("Quit Card Sharks?", 34, Palette.FOAM)
	_show_popup(l, "", [{"label": "Quit", "enabled": true, "cb": func(): get_tree().quit()}])


func _check_orientation() -> void:
	var s := get_viewport_rect().size
	_rotate_overlay.visible = s.y > s.x
	_update_fullscreen_button()
	if enc:
		_refresh.call_deferred()   # market tiles are sized to the screen size
	_snap_to_viewport.call_deferred()


## During a fullscreen <-> window switch the viewport briefly reports odd
## sizes; containers that grew then keep stale offsets and push the hand off
## screen. Re-pin everything to the viewport once things settle.
func _snap_to_viewport() -> void:
	var vp := get_viewport_rect().size
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_deferred("size", vp)
	for c in get_children():
		if c is Control:
			(c as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			(c as Control).position = Vector2.ZERO
			(c as Control).set_deferred("size", vp)
	# The window can settle a few frames later; check once more.
	if not _snap_again_pending:
		_snap_again_pending = true
		await get_tree().create_timer(0.25).timeout
		_snap_again_pending = false
		if not _margin.size.is_equal_approx(get_viewport_rect().size):
			_snap_to_viewport()


func _is_fullscreen() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _toggle_fullscreen() -> void:
	if _is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		if not OS.has_feature("web"):
			# Leaving fullscreen keeps the full-screen size (title bar off-screen)
			# unless we give the window a sensible size and centre it.
			await get_tree().process_frame
			_center_window()
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		if OS.has_feature("web"):
			# Lock to landscape on phones that support it (needs fullscreen).
			JavaScriptBridge.eval("try { screen.orientation.lock('landscape').catch(function(){}); } catch (e) {}")
	_update_fullscreen_button.call_deferred()


## Windowed mode: 16:9 window at 80% of the usable screen, centred.
func _center_window() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var base := Vector2(1280, 720)
	var f := minf(usable.size.x * 0.8 / base.x, usable.size.y * 0.8 / base.y)
	var sz := Vector2i(base * f)
	DisplayServer.window_set_size(sz)
	DisplayServer.window_set_position(usable.position + Vector2i(Vector2(usable.size - sz) * 0.5))


func _update_fullscreen_button() -> void:
	if _fs_button:
		_fs_button.text = "Window" if _is_fullscreen() else "Fullscreen"


func _unhandled_input(event: InputEvent) -> void:
	# Esc leaves fullscreen (desktop).
	if event.is_action_pressed("ui_cancel") and _is_fullscreen() and not OS.has_feature("web"):
		get_viewport().set_input_as_handled()
		_toggle_fullscreen()

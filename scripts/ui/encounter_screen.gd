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
@export var loadout: LoadoutData

enum ShopTab { CARDS, ITEMS, TRINKETS, UPGRADES }

const LARGE_W := 340.0

var enc: Encounter
var shop_tab: ShopTab = ShopTab.CARDS
var pending_enh_slot := -1

var _round_label: Label
var _coins_label: Label
var _coins_bar: ProgressBar
var _enemy_name: Label
var _enemy_sub: Label
var _enemy_portrait_label: Label
var _enemy_portrait: PanelContainer
var _enemy_chips: HBoxContainer
var _enemy_pips: HBoxContainer
var _intent_bubble: PanelContainer
var _intent_title: Label
var _intent_kind: Label
var _intent_desc: RichTextLabel
var _tab_buttons: Array[Button] = []
var _shop_panel: PanelContainer
var _shop_row: HBoxContainer
var _table: Control            ## middle of the screen, where played cards resolve
var _table_hint: Label         ## only used for the enhancement picker
var _trinkets_panel: DropTarget
var _trinkets_box: VBoxContainer
var _items_panel: DropTarget
var _items_box: VBoxContainer
var _rotate_overlay: Control
var _hand: HandView
var _pile: PileView
var _pass_btn: Button
var _fx_layer: Control
var _popup_layer: Control
var _log_text := ""
var _enemy_timer: Timer
var _shop_drag := {}
var _last_coins := -1
var _last_enemy_coins := -1
var _last_round := 0


func _ready() -> void:
	_build_ui()
	_enemy_timer = Timer.new()
	_enemy_timer.one_shot = true
	_enemy_timer.wait_time = GameRules.ENEMY_STEP_DELAY
	_enemy_timer.timeout.connect(_on_enemy_timer)
	add_child(_enemy_timer)

	if encounter_data == null or loadout == null:
		_table_hint.text = "Assign encounter_data and loadout on the Main node."
		return
	enc = Encounter.new(encounter_data, loadout)
	enc.logged.connect(func(t: String): _log_text += t + "\n")
	enc.changed.connect(_refresh)
	enc.enemy_turn_pending.connect(_on_enemy_pending)
	enc.ended.connect(_show_end_overlay)
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
	for c in _shop_row.get_children():
		rects.append((c as Control).get_global_rect())
	var was_cards_tab := shop_tab == ShopTab.CARDS
	enc.enemy_act()
	if was_cards_tab:
		for i in mini(before.size(), rects.size()):
			if before[i] != null and enc.shop.cards[i] != before[i]:
				var ghost := _card_data_view(before[i], CardView.SMALL)
				_add_fx(ghost, rects[i].get_center())
				Fx.fly_into(ghost, _enemy_portrait.get_global_rect().get_center(), Callable(), 0.55)


func _on_card_dropped(card: Variant, at_global: Vector2) -> void:
	if pending_enh_slot >= 0:
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
	Fx.resolve(ghost, _table.get_global_rect().get_center())


func _on_hand_tapped(card: Variant) -> void:
	var c: CardInstance = card
	if pending_enh_slot >= 0:
		var slot := pending_enh_slot
		pending_enh_slot = -1
		if not enc.buy_enhancement(slot, c):
			_refresh()
		return
	_show_popup(_card_instance_view(c, CardView.LARGE), c.data.flavor_text, [
		{"label": "Play" + (" (free)" if c.is_instant() else ""), "enabled": enc.can_play(c),
			"cb": func(): _play_with_fx(c, _hand.card_center(c))},
	])


## Adds `view` to the effects layer centred on `center_global`.
func _add_fx(view: Control, center_global: Vector2) -> void:
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(view)
	view.size = view.custom_minimum_size
	view.global_position = center_global - view.size * 0.5


# =============================================================== refresh

func _refresh() -> void:
	if enc == null:
		return
	var me := enc.player
	var my_turn := enc.is_player_turn()

	# Top bar + coin change pop-ups.
	_round_label.text = "Round %d/%d" % [enc.round_num, enc.data.rounds]
	_coins_label.text = "%d / %d" % [me.coins, enc.data.coin_target]
	_coins_bar.max_value = enc.data.coin_target
	_coins_bar.value = mini(me.coins, enc.data.coin_target)
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
	_enemy_sub.text = "%d coins" % enc.enemy.coins
	_enemy_portrait_label.text = enc.enemy.display_name.get_slice(" ", enc.enemy.display_name.get_slice_count(" ") - 1).left(1)
	var ecol: Color = enc.data.enemy.color if enc.data.enemy else Palette.CORAL
	_enemy_portrait.add_theme_stylebox_override("panel", Palette.box(ecol.darkened(0.5), ecol, 48, 3, 0))
	var intent := enc.current_intent()
	_intent_desc.clear()
	if intent:
		_intent_title.text = intent.display_name
		_intent_kind.text = "NEXT · " + EnemyIntent.kind_label(intent.kind)
		Icons.append(_intent_desc, intent.get_description(), 19)
	else:
		_intent_title.text = "—"
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
		_enemy_chips.add_child(_chip(item.data.display_name, Palette.CARD_ITEM, false,
			func(): _show_popup(_item_view(item.data, false), "", [], "Enemy item")))

	# Market.
	var counts := [_count(enc.shop.cards), _count(enc.shop.items), _count(enc.shop.trinkets), _count(enc.shop.enhancements)]
	var names := ["Cards", "Items", "Trinkets", "Upgrades"]
	var slots := [enc.shop.cards.size(), enc.shop.items.size(), enc.shop.trinkets.size(), enc.shop.enhancements.size()]
	for i in _tab_buttons.size():
		_tab_buttons[i].text = "%s %d" % [names[i], counts[i]]
		_tab_buttons[i].visible = slots[i] > 0   # hide categories this shop doesn't sell
		_tab_buttons[i].button_pressed = (i == shop_tab)
	_fill_shop()

	# Your trinkets / items.
	_clear(_trinkets_box)
	for i in me.trinkets.size():
		var t := me.trinkets[i]
		var idx := i
		var usable := enc.can_use_trinket(idx)
		var chip := _chip(t.get_name(), Palette.CARD_TRINKET, usable, func(): _show_trinket_popup(idx))
		chip.modulate = Color.WHITE if usable else Color(0.7, 0.7, 0.7)
		_trinkets_box.add_child(chip)
	if me.trinkets.is_empty():
		_trinkets_box.add_child(_empty_gear_slot())
	_clear(_items_box)
	for it in me.items:
		var item: ItemInstance = it
		_items_box.add_child(_chip(item.data.display_name, Palette.CARD_ITEM, false,
			func(): _show_popup(_item_view(item.data, false), "", [], "Passive — always on")))
	if me.items.is_empty():
		_items_box.add_child(_empty_gear_slot())

	# Hand (dimmed while the enemy acts).
	var views: Array[CardView] = []
	for c in me.hand:
		var v := _card_instance_view(c, CardView.HAND)
		v.payload = c
		if pending_enh_slot >= 0:
			v.set_enabled(enc.can_buy_enhancement(pending_enh_slot, c))
			v.set_highlighted(true)
		else:
			v.set_enabled(enc.can_play(c))
			v.dim_when_disabled = false
		views.append(v)
	_hand.set_views(views)
	_hand.modulate = Color.WHITE if my_turn or enc.is_over else Color(0.6, 0.62, 0.7)

	_pile.set_counts(me.draw_pile.size(), me.discard.size() + me.in_play.size())
	_pass_btn.disabled = not my_turn or pending_enh_slot >= 0
	_pass_btn.text = "Pass" if enc.round_num < enc.data.rounds else "Finish"
	_table_hint.text = "Tap a card in your hand to enhance it" if pending_enh_slot >= 0 else ""


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
	l.global_position = _table.get_global_rect().get_center() - l.size * 0.5
	l.modulate.a = 0.0
	l.scale = Vector2(0.7, 0.7)
	var tw := l.create_tween()
	tw.set_parallel().tween_property(l, "modulate:a", 1.0, 0.25)
	tw.tween_property(l, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.6)
	tw.chain().tween_property(l, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(l.queue_free)


func _empty_gear_slot() -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 44)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", Palette.box(Color.TRANSPARENT, Palette.MUTED.darkened(0.45), 22, 2, 0))
	var l := CardView._label("+", 26, Palette.MUTED.darkened(0.3))
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


# ================================================================ market

func _fill_shop() -> void:
	_clear(_shop_row)
	match shop_tab:
		ShopTab.CARDS:
			for slot in enc.shop.cards.size():
				var cd: CardData = enc.shop.cards[slot]
				if cd == null:
					_shop_row.add_child(_empty_slot()); continue
				var s := slot
				var v := _card_data_view(cd, CardView.SMALL)
				v.set_enabled(enc.can_buy_card(s))
				var make := func(): return _card_data_view(cd, CardView.SMALL)
				_attach_buy_drag(v, func(): return enc.buy_card(s), _pile, make)
				v.tapped.connect(func(): _show_popup(_card_data_view(cd, CardView.LARGE), cd.flavor_text, [
					{"label": "Buy (%d)" % cd.cost, "enabled": enc.can_buy_card(s),
						"cb": func(): _buy_with_fx(func(): return enc.buy_card(s), make.call(), _pile)}]))
				_shop_row.add_child(v)
		ShopTab.ITEMS:
			for slot in enc.shop.items.size():
				var it: ItemData = enc.shop.items[slot]
				if it == null:
					_shop_row.add_child(_empty_slot()); continue
				var s := slot
				var v := _item_view(it, true)
				v.set_enabled(enc.can_buy_item(s))
				var make := func(): return _item_view(it, true)
				_attach_buy_drag(v, func(): return enc.buy_item(s), _items_panel, make)
				v.tapped.connect(func(): _show_popup(_item_view(it, true, CardView.LARGE), "", [
					{"label": "Buy (%d)" % it.cost, "enabled": enc.can_buy_item(s),
						"cb": func(): _buy_with_fx(func(): return enc.buy_item(s), make.call(), _items_panel)}]))
				_shop_row.add_child(v)
		ShopTab.TRINKETS:
			for slot in enc.shop.trinkets.size():
				var td: TrinketData = enc.shop.trinkets[slot]
				if td == null:
					_shop_row.add_child(_empty_slot()); continue
				var s := slot
				var v := _trinket_data_view(td, CardView.SMALL)
				v.set_enabled(enc.can_buy_trinket(s))
				var make := func(): return _trinket_data_view(td, CardView.SMALL)
				_attach_buy_drag(v, func(): return enc.buy_trinket(s), _trinkets_panel, make)
				v.tapped.connect(func(): _show_popup(_trinket_data_view(td, CardView.LARGE), "", [
					{"label": "Buy (%d)" % td.cost, "enabled": enc.can_buy_trinket(s),
						"cb": func(): _buy_with_fx(func(): return enc.buy_trinket(s), make.call(), _trinkets_panel)}]))
				_shop_row.add_child(v)
		ShopTab.UPGRADES:
			for slot in enc.shop.enhancements.size():
				var ed: EnhancementData = enc.shop.enhancements[slot]
				if ed == null:
					_shop_row.add_child(_empty_slot()); continue
				var s := slot
				var v := CardView.make(ed.display_name, ed.cost, ed.get_description(), Palette.CARD_ENH, CardView.SMALL, "UPGRADE")
				v.set_enabled(enc.can_buy_enhancement(s))
				v.tapped.connect(func(): _show_popup(
					CardView.make(ed.display_name, ed.cost, ed.get_description(), Palette.CARD_ENH, CardView.LARGE, "UPGRADE"), ed.description, [
					{"label": "Choose card (%d)" % ed.cost, "enabled": enc.can_buy_enhancement(s),
						"cb": func(): pending_enh_slot = s; _refresh()}]))
				_shop_row.add_child(v)
	if _shop_row.get_child_count() == 0:
		_shop_row.add_child(CardView._label("Nothing for sale", 18, Palette.MUTED))


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
	for section in [["Deck", draw_sorted, "(not in draw order)"], ["Hand", me.hand, ""],
			["Played this round", me.in_play, ""], ["Discard", me.discard, ""]]:
		var cards: Array = section[1]
		vb.add_child(CardView._label("%s  (%d)  %s" % [section[0], cards.size(), section[2]], 20, Palette.KELP))
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


# ================================================================= views

func _card_body(play: String, buy: String) -> String:
	var s := ""
	if play != "":
		s += "[color=#7fe3d0]Play:[/color] " + play
	if buy != "":
		s += ("\n" if s != "" else "") + "[color=#ffd166]On buy:[/color] " + buy
	return s


func _card_data_view(cd: CardData, sz: Vector2) -> CardView:
	return CardView.make(cd.display_name, cd.cost,
		_card_body(cd.get_play_text(_vars()), cd.get_buy_text(_vars())),
		Palette.CARD, sz, "INSTANT" if cd.instant and not cd.has_custom_text() else "")


func _card_instance_view(c: CardInstance, sz: Vector2) -> CardView:
	var footer := ""
	for e in c.enhancements:
		footer += "+ " + e.display_name + "  "
	return CardView.make(c.get_name(), c.get_cost(), _card_body(c.play_text(_vars()), c.buy_text(_vars())),
		Palette.CARD, sz, "INSTANT" if c.is_instant() and not c.data.has_custom_text() else "", footer.strip_edges())


func _vars() -> Dictionary:
	return enc.text_vars() if enc else {}


func _item_view(it: ItemData, show_cost: bool, sz: Vector2 = CardView.SMALL) -> CardView:
	return CardView.make(it.display_name, it.cost if show_cost else -1, it.get_description(), Palette.CARD_ITEM, sz, "ITEM")


func _trinket_data_view(td: TrinketData, sz: Vector2) -> CardView:
	var desc := td.levels[0].get_text() if not td.levels.is_empty() else ""
	if td.description != "":
		desc = td.description + "\n" + desc
	return CardView.make(td.display_name, td.cost, "Once per round (free): " + desc, Palette.CARD_TRINKET, sz, "TRINKET")


func _show_trinket_popup(idx: int) -> void:
	var t := enc.player.trinkets[idx]
	var actions := [{"label": "Use (free)", "enabled": enc.can_use_trinket(idx), "cb": func(): enc.use_trinket(idx)}]
	if t.can_upgrade():
		actions.append({"label": "Upgrade (%d)" % t.upgrade_cost(), "enabled": enc.can_upgrade_trinket(idx),
			"cb": func(): enc.upgrade_trinket(idx)})
	_show_popup(CardView.make(t.get_name(), -1, t.get_description(), Palette.CARD_TRINKET, CardView.LARGE,
		"TRINKET" + (" · used this round" if t.used else "")), "", actions,
		"Using is free. " + ("Upgrading uses your action." if GameRules.TRINKET_UPGRADE_IS_ACTION else ""))


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


func _empty_slot() -> Control:
	var v := CardView.make("—", -1, "Sold out", Palette.DEEP, CardView.SMALL)
	v.set_enabled(false)
	return v


func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


# ================================================================ popups

## Generic modal: dims the screen, shows `content` plus action buttons.
## Tap outside to close.
func _show_popup(content: Control, subtitle: String, actions: Array, note := "") -> void:
	_close_popup()
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.03, 0.07, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed: _close_popup())
	_popup_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_layer.add_child(center)
	# Landscape: content on the left, text + buttons stacked on the right.
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 28)
	center.add_child(hb)
	if content is CardView:
		(content as CardView).dim_when_disabled = false
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
	close.pressed.connect(_close_popup)
	vb.add_child(close)


func _close_popup() -> void:
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
	var d := CardView._label("You finished with %d / %d coins." % [enc.player.coins, enc.data.coin_target]
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
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	_enemy_sub = CardView._label("", 16, Palette.MUTED)
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
	_intent_desc = Icons.rich_label("", 17, Palette.FOAM.darkened(0.1))
	ib.add_child(_intent_desc)
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
	for pair in [["Log", _show_log], ["Fullscreen", _toggle_fullscreen]]:
		var b := _big_button(pair[0], Palette.PANEL)
		b.custom_minimum_size = Vector2(0, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(pair[1])
		left_bottom.add_child(b)

	# ================= RIGHT: market, table, hand
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	main.add_child(right)

	_shop_panel = PanelContainer.new()
	_shop_panel.add_theme_stylebox_override("panel", Palette.box(Palette.DEEP, Palette.TEAL.darkened(0.55), 16, 2, 10))
	right.add_child(_shop_panel)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 12)
	_shop_panel.add_child(sh)
	var tabs := VBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	tabs.custom_minimum_size.x = 150
	sh.add_child(tabs)
	tabs.add_child(CardView._label("MARKET", 15, Palette.KELP))
	var group := ButtonGroup.new()
	for i in 4:
		var t := Button.new()
		t.toggle_mode = true
		t.button_group = group
		t.size_flags_vertical = Control.SIZE_EXPAND_FILL
		t.custom_minimum_size.y = 36
		t.alignment = HORIZONTAL_ALIGNMENT_LEFT
		t.add_theme_font_size_override("font_size", 18)
		t.add_theme_stylebox_override("normal", Palette.box(Palette.PANEL.darkened(0.2), Color.TRANSPARENT, 10, 0, 8))
		t.add_theme_stylebox_override("hover", Palette.box(Palette.PANEL, Color.TRANSPARENT, 10, 0, 8))
		t.add_theme_stylebox_override("pressed", Palette.box(Palette.TEAL.darkened(0.45), Palette.TEAL, 10, 2, 8))
		t.add_theme_color_override("font_color", Palette.MUTED)
		t.add_theme_color_override("font_pressed_color", Palette.FOAM)
		var idx := i
		t.pressed.connect(func(): shop_tab = idx as ShopTab; _refresh())
		tabs.add_child(t)
		_tab_buttons.append(t)
	_shop_row = HBoxContainer.new()
	_shop_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_shop_row.add_theme_constant_override("separation", 8)
	_shop_row.custom_minimum_size.y = CardView.SMALL.y
	sh.add_child(_shop_row)

	# The table: empty space where played cards resolve.
	_table = Control.new()
	_table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_table.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and pending_enh_slot >= 0:
			pending_enh_slot = -1
			_refresh())
	right.add_child(_table)
	_table_hint = CardView._label("", 22, Palette.MUTED)
	_table_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_table_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_table_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_table.add_child(_table_hint)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	right.add_child(bottom)
	_hand = HandView.new()
	_hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand.custom_minimum_size.y = CardView.HAND.y + 36
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
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.z_index = 400   # above the fanned hand
	add_child(_fx_layer)

	_popup_layer = Control.new()
	_popup_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_layer.z_index = 500
	add_child(_popup_layer)

	# Shown when a phone is held upright.
	_rotate_overlay = ColorRect.new()
	(_rotate_overlay as ColorRect).color = Palette.ABYSS
	_rotate_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rotate_overlay.z_index = 1000
	_rotate_overlay.visible = false
	add_child(_rotate_overlay)
	var rc := CenterContainer.new()
	rc.set_anchors_preset(Control.PRESET_FULL_RECT)
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


func _check_orientation() -> void:
	var s := get_viewport_rect().size
	_rotate_overlay.visible = s.y > s.x


func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		if OS.has_feature("web"):
			# Lock to landscape on phones that support it (needs fullscreen).
			JavaScriptBridge.eval("try { screen.orientation.lock('landscape').catch(function(){}); } catch (e) {}")



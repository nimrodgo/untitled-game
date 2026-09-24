extends Control
## Landscape (mobile-friendly) encounter screen, built in code so it's easy to
## swap for real scenes/art later. Talks only to Encounter.
##
## Interaction model: tap anything to inspect it (popup with its actions);
## drag cards from your hand into the play zone to play them.

@export var encounter_data: EncounterData
@export var loadout: LoadoutData

enum ShopTab { CARDS, ITEMS, TRINKETS, UPGRADES }

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
var _intent_bubble: PanelContainer
var _intent_title: Label
var _intent_kind: Label
var _intent_desc: RichTextLabel
var _tab_buttons: Array[Button] = []
var _shop_row: HBoxContainer
var _play_zone: PanelContainer
var _play_hint: Label
var _ticker: RichTextLabel
var _gear_row: VBoxContainer
var _rotate_overlay: Control
var _hand: HandView
var _pile_label: Label
var _pass_btn: Button
var _popup_layer: Control
var _log_text := ""
var _recent: PackedStringArray = []
var _enemy_timer: Timer


func _ready() -> void:
	_build_ui()
	_enemy_timer = Timer.new()
	_enemy_timer.one_shot = true
	_enemy_timer.wait_time = GameRules.ENEMY_STEP_DELAY
	_enemy_timer.timeout.connect(func(): if enc: enc.enemy_act())
	add_child(_enemy_timer)

	if encounter_data == null or loadout == null:
		_play_hint.text = "Assign encounter_data and loadout on the Main node."
		return
	enc = Encounter.new(encounter_data, loadout)
	enc.logged.connect(_on_log)
	enc.changed.connect(_refresh)
	enc.enemy_turn_pending.connect(_on_enemy_pending)
	enc.ended.connect(_show_end_overlay)
	enc.start()


# ================================================================== flow

func _on_enemy_pending() -> void:
	var tw := _intent_bubble.create_tween()
	_intent_bubble.pivot_offset = _intent_bubble.size * 0.5
	tw.tween_property(_intent_bubble, "scale", Vector2(1.12, 1.12), 0.2).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_intent_bubble, "scale", Vector2.ONE, 0.25)
	_enemy_timer.start()


func _on_log(text: String) -> void:
	_log_text += text + "\n"
	var t := text.strip_edges()
	if t != "":
		_recent.append(t)
		if _recent.size() > 3:
			_recent = _recent.slice(_recent.size() - 3)
	if _ticker:
		_ticker.text = "\n".join(_recent)


func _on_card_dropped(card: Variant) -> void:
	if pending_enh_slot >= 0 or not enc.play_card(card):
		_hand._layout(true)   # snap back


func _on_hand_tapped(card: Variant) -> void:
	var c: CardInstance = card
	if pending_enh_slot >= 0:
		var slot := pending_enh_slot
		pending_enh_slot = -1
		if not enc.buy_enhancement(slot, c):
			_refresh()
		return
	_show_popup(_card_instance_view(c, CardView.LARGE), c.data.flavor_text, [
		{"label": "Play" + (" (free)" if c.is_instant() else ""), "enabled": enc.can_play(c), "cb": func(): enc.play_card(c)},
	], "Tip: drag cards up to play them.")


# =============================================================== refresh

func _refresh() -> void:
	if enc == null:
		return
	var me := enc.player
	var my_turn := enc.is_player_turn()

	# Top bar.
	_round_label.text = "Round %d/%d" % [enc.round_num, enc.data.rounds]
	_coins_label.text = "%d / %d" % [me.coins, enc.data.coin_target]
	_coins_bar.max_value = enc.data.coin_target
	_coins_bar.value = mini(me.coins, enc.data.coin_target)

	# Enemy.
	_enemy_name.text = enc.enemy.display_name
	_enemy_sub.text = "%d coins" % enc.enemy.coins
	_enemy_portrait_label.text = enc.enemy.display_name.get_slice(" ", enc.enemy.display_name.get_slice_count(" ") - 1).left(1)
	var ecol: Color = enc.data.enemy.color if enc.data.enemy else Palette.CORAL
	_enemy_portrait.add_theme_stylebox_override("panel", Palette.box(ecol.darkened(0.5), ecol, 48, 3, 0))
	var intent := enc.current_intent()
	if intent:
		_intent_title.text = intent.display_name
		_intent_kind.text = "NEXT ACTION · " + EnemyIntent.kind_label(intent.kind)
		_intent_desc.clear()
		Icons.append(_intent_desc, intent.get_description(), 19)
	else:
		_intent_title.text = "—"
		_intent_desc.clear()
		_intent_desc.append_text("No intents")
	_clear(_enemy_chips)
	for it in enc.enemy.items:
		var item: ItemInstance = it
		_enemy_chips.add_child(_chip(item.data.display_name, Palette.CARD_ITEM, false,
			func(): _show_popup(_item_view(item.data, false), "", [], "Enemy item")))

	# Shop tabs.
	var counts := [_count(enc.shop.cards), _count(enc.shop.items), _count(enc.shop.trinkets), _count(enc.shop.enhancements)]
	var names := ["Cards", "Items", "Trinkets", "Upgrades"]
	var slots := [enc.shop.cards.size(), enc.shop.items.size(), enc.shop.trinkets.size(), enc.shop.enhancements.size()]
	for i in _tab_buttons.size():
		_tab_buttons[i].text = "%s %d" % [names[i], counts[i]]
		_tab_buttons[i].visible = slots[i] > 0   # hide categories this shop doesn't sell
		_tab_buttons[i].button_pressed = (i == shop_tab)
	_fill_shop()

	# Play zone.
	_play_zone.add_theme_stylebox_override("panel", Palette.box(Palette.DEEP.lerp(Palette.ABYSS, 0.5), Palette.TEAL.darkened(0.5), 16, 2, 14))
	if enc.is_over:
		_play_hint.text = "Encounter over"
	elif pending_enh_slot >= 0:
		_play_hint.text = "Tap a card in your hand to enhance it\n(tap here to cancel)"
	elif my_turn:
		_play_hint.text = "Drag a card here to play it"
	else:
		_play_hint.text = "%s is acting…" % enc.enemy.display_name

	# Gear.
	_clear(_gear_row)
	for i in me.trinkets.size():
		var t := me.trinkets[i]
		var idx := i
		var usable := enc.can_use_trinket(idx)
		_gear_row.add_child(_chip(t.get_name() + (" · USE" if usable else ""), Palette.CARD_TRINKET, usable,
			func(): _show_trinket_popup(idx)))
	for it in me.items:
		var item: ItemInstance = it
		_gear_row.add_child(_chip(item.data.display_name, Palette.CARD_ITEM, false,
			func(): _show_popup(_item_view(item.data, false), "", [], "Passive — always on")))
	if me.trinkets.is_empty() and me.items.is_empty():
		var l := CardView._label("No items or trinkets yet.\nBuy them in the market.", 16, Palette.MUTED)
		_gear_row.add_child(l)

	# Hand.
	var views: Array[CardView] = []
	for c in me.hand:
		var v := _card_instance_view(c, CardView.HAND)
		v.payload = c
		if pending_enh_slot >= 0:
			v.set_enabled(enc.can_buy_enhancement(pending_enh_slot, c))
			v.set_highlighted(true)
		else:
			v.set_enabled(enc.can_play(c))
		views.append(v)
	_hand.set_views(views)

	# Bottom bar.
	_pile_label.text = "Deck %d   Discard %d" % [me.draw_pile.size(), me.discard.size() + me.in_play.size()]
	_pass_btn.disabled = not my_turn or pending_enh_slot >= 0
	_pass_btn.text = "Pass" if enc.round_num < enc.data.rounds else "Finish"


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
				v.tapped.connect(func(): _show_popup(_card_data_view(cd, CardView.LARGE), cd.flavor_text, [
					{"label": "Buy (%d)" % cd.cost, "enabled": enc.can_buy_card(s), "cb": func(): enc.buy_card(s)}],
					_action_note(GameRules.CARD_BUY_IS_ACTION)))
				_shop_row.add_child(v)
		ShopTab.ITEMS:
			for slot in enc.shop.items.size():
				var it: ItemData = enc.shop.items[slot]
				if it == null:
					_shop_row.add_child(_empty_slot()); continue
				var s := slot
				var v := _item_view(it, true)
				v.set_enabled(enc.can_buy_item(s))
				v.tapped.connect(func(): _show_popup(_item_view(it, true, CardView.LARGE), "", [
					{"label": "Buy (%d)" % it.cost, "enabled": enc.can_buy_item(s), "cb": func(): enc.buy_item(s)}],
					_action_note(GameRules.ITEM_BUY_IS_ACTION)))
				_shop_row.add_child(v)
		ShopTab.TRINKETS:
			for slot in enc.shop.trinkets.size():
				var td: TrinketData = enc.shop.trinkets[slot]
				if td == null:
					_shop_row.add_child(_empty_slot()); continue
				var s := slot
				var v := _trinket_data_view(td, CardView.SMALL)
				v.set_enabled(enc.can_buy_trinket(s))
				v.tapped.connect(func(): _show_popup(_trinket_data_view(td, CardView.LARGE), "", [
					{"label": "Buy (%d)" % td.cost, "enabled": enc.can_buy_trinket(s), "cb": func(): enc.buy_trinket(s)}],
					_action_note(GameRules.TRINKET_BUY_IS_ACTION)))
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
						"cb": func(): pending_enh_slot = s; _refresh()}],
					"Applies to a card in your hand. " + _action_note(GameRules.ENHANCEMENT_BUY_IS_ACTION)))
				_shop_row.add_child(v)
	if _shop_row.get_child_count() == 0:
		_shop_row.add_child(CardView._label("Nothing for sale", 18, Palette.MUTED))


func _action_note(is_action: bool) -> String:
	return "Uses your action for this turn." if is_action else "Free action."


func _count(arr: Array) -> int:
	var n := 0
	for x in arr:
		if x != null:
			n += 1
	return n


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
	return CardView.make(td.display_name, td.cost, "Once per turn (free): " + desc, Palette.CARD_TRINKET, sz, "TRINKET")


func _show_trinket_popup(idx: int) -> void:
	var t := enc.player.trinkets[idx]
	var actions := [{"label": "Use (free)", "enabled": enc.can_use_trinket(idx), "cb": func(): enc.use_trinket(idx)}]
	if t.can_upgrade():
		actions.append({"label": "Upgrade (%d)" % t.upgrade_cost(), "enabled": enc.can_upgrade_trinket(idx),
			"cb": func(): enc.upgrade_trinket(idx)})
	_show_popup(CardView.make(t.get_name(), -1, t.get_description(), Palette.CARD_TRINKET, CardView.LARGE,
		"TRINKET" + (" · used this turn" if t.used else "")), "", actions,
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
	_show_popup(vb, "", [], "%s acts after each of your actions, in this order." % enc.enemy.display_name)


const LARGE_W := 340.0


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


# ================================================================= build

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

	# ================= LEFT COLUMN: status, enemy, your gear
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
	_enemy_portrait.custom_minimum_size = Vector2(76, 76)
	eh.add_child(_enemy_portrait)
	_enemy_portrait_label = CardView._label("?", 36, Palette.FOAM)
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
	_intent_bubble = PanelContainer.new()
	_intent_bubble.add_theme_stylebox_override("panel", Palette.box(Palette.CORAL.darkened(0.55), Palette.CORAL, 14, 3, 12))
	_intent_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	_intent_bubble.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT and enc: _show_intents_popup())
	ev.add_child(_intent_bubble)
	var ib := VBoxContainer.new()
	ib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intent_bubble.add_child(ib)
	_intent_kind = CardView._label("NEXT ACTION", 14, Palette.CORAL)
	ib.add_child(_intent_kind)
	_intent_title = CardView._label("", 26, Palette.FOAM)
	ib.add_child(_intent_title)
	_intent_desc = Icons.rich_label("", 17, Palette.FOAM.darkened(0.1))
	ib.add_child(_intent_desc)
	_enemy_chips = HBoxContainer.new()
	_enemy_chips.add_theme_constant_override("separation", 6)
	ev.add_child(_enemy_chips)

	# Your gear (trinkets + items), scrollable.
	left.add_child(CardView._label("YOUR GEAR", 14, Palette.KELP))
	var gear_scroll := ScrollContainer.new()
	gear_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gear_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(gear_scroll)
	_gear_row = VBoxContainer.new()
	_gear_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gear_row.add_theme_constant_override("separation", 6)
	gear_scroll.add_child(_gear_row)

	var left_bottom := HBoxContainer.new()
	left_bottom.add_theme_constant_override("separation", 8)
	left.add_child(left_bottom)
	var log_btn := _big_button("Log", Palette.PANEL)
	log_btn.custom_minimum_size = Vector2(0, 56)
	log_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_btn.add_theme_font_size_override("font_size", 19)
	log_btn.pressed.connect(_show_log)
	left_bottom.add_child(log_btn)
	var fs_btn := _big_button("Fullscreen", Palette.PANEL)
	fs_btn.custom_minimum_size = Vector2(0, 56)
	fs_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_btn.add_theme_font_size_override("font_size", 19)
	fs_btn.pressed.connect(_toggle_fullscreen)
	left_bottom.add_child(fs_btn)

	# ================= RIGHT: shop, play zone, hand
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	main.add_child(right)

	var shop_panel := PanelContainer.new()
	shop_panel.add_theme_stylebox_override("panel", Palette.box(Palette.DEEP, Palette.TEAL.darkened(0.55), 16, 2, 10))
	right.add_child(shop_panel)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 12)
	shop_panel.add_child(sh)
	# Vertical tabs on the left of the shop row.
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

	_play_zone = PanelContainer.new()
	_play_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_play_zone.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and pending_enh_slot >= 0:
			pending_enh_slot = -1
			_refresh())
	right.add_child(_play_zone)
	var pz := HBoxContainer.new()
	pz.add_theme_constant_override("separation", 20)
	pz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_zone.add_child(pz)
	_play_hint = CardView._label("", 22, Palette.MUTED)
	_play_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_hint.size_flags_stretch_ratio = 0.8
	_play_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_play_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_play_hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pz.add_child(_play_hint)
	_ticker = RichTextLabel.new()
	_ticker.bbcode_enabled = true
	_ticker.scroll_active = false
	_ticker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ticker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ticker.fit_content = true
	_ticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ticker.add_theme_font_size_override("normal_font_size", 17)
	_ticker.add_theme_font_size_override("bold_font_size", 17)
	_ticker.add_theme_color_override("default_color", Palette.MUTED)
	pz.add_child(_ticker)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	right.add_child(bottom)
	_hand = HandView.new()
	_hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand.custom_minimum_size.y = CardView.HAND.y + 24
	_hand.drop_zone = _play_zone
	_hand.card_dropped.connect(_on_card_dropped)
	_hand.card_tapped.connect(_on_hand_tapped)
	_hand.dragging_changed.connect(func(d: bool):
		_play_zone.add_theme_stylebox_override("panel", Palette.box(
			Palette.TEAL.darkened(0.7) if d else Palette.DEEP.lerp(Palette.ABYSS, 0.5),
			Palette.GOLD if d else Palette.TEAL.darkened(0.5), 16, 3 if d else 2, 14)))
	bottom.add_child(_hand)
	var pass_col := VBoxContainer.new()
	pass_col.alignment = BoxContainer.ALIGNMENT_END
	pass_col.add_theme_constant_override("separation", 8)
	bottom.add_child(pass_col)
	_pile_label = CardView._label("", 17, Palette.MUTED)
	_pile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pass_col.add_child(_pile_label)
	_pass_btn = _big_button("Pass", Palette.CORAL)
	_pass_btn.custom_minimum_size = Vector2(150, 90)
	_pass_btn.pressed.connect(func(): enc.pass_turn())
	pass_col.add_child(_pass_btn)

	_popup_layer = Control.new()
	_popup_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_layer.z_index = 500   # above the fanned hand cards
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

class_name CardView
extends PanelContainer
## Generic tile used for cards, items, trinkets, enhancements and intents.
## Emits `tapped` on a short press-release (not after a drag/scroll).

signal tapped

const SMALL := Vector2(124, 184)
const HAND := Vector2(144, 200)
const LARGE := Vector2(360, 500)

const TAP_SLOP := 16.0

var enabled := true
var highlighted := false
## Read-only tiles stay fully opaque even when not interactive.
var dim_when_disabled := true
## Whatever the owner wants to attach (CardInstance, slot index, ...).
var payload: Variant

var _bg: Color = Palette.CARD
var _accent: Color = Palette.TEAL
var _pressed := false
var _press_pos := Vector2.ZERO


static func make(title: String, cost: int, body: String, bg: Color = Palette.CARD,
		min_size: Vector2 = SMALL, tag := "", footer := "") -> CardView:
	var v := CardView.new()
	v._bg = bg
	v.custom_minimum_size = min_size
	v.size = min_size
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	var big := min_size.x >= LARGE.x * 0.9
	var k := 1.7 if big else (1.1 if min_size.x >= HAND.x else 1.0)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(4 * k))
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(vb)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(top)
	var name_l := _label(title, int((18 if big else 16) * k), Palette.FOAM)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(name_l)
	if cost >= 0:
		var cost_l := _label("%d" % cost, int(22 * k), Palette.ABYSS)
		cost_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var coin := PanelContainer.new()
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.custom_minimum_size = Vector2(30, 30) * k
		coin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		coin.add_theme_stylebox_override("panel", Palette.box(Palette.GOLD, Color.TRANSPARENT, int(15 * k), 0, 0))
		coin.add_child(cost_l)
		top.add_child(coin)

	if tag != "":
		vb.add_child(_label(tag, int(13 * k), Palette.KELP))

	var body_l := _label(body, int(16 * k), Palette.FOAM.darkened(0.12))
	body_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if not big:
		# Small tiles show a preview; tap for the full text.
		body_l.max_lines_visible = 5 if tag == "" else 4
		body_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_l.max_lines_visible = 2
	vb.add_child(body_l)

	if footer != "":
		var f := _label(footer, int(14 * k), Palette.CORAL)
		f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(f)

	v._restyle()
	return v


static func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func set_enabled(value: bool) -> void:
	enabled = value
	_restyle()


func set_highlighted(value: bool) -> void:
	highlighted = value
	_restyle()


func _restyle() -> void:
	var border := _accent.darkened(0.4)
	var bw := 2
	if highlighted:
		border = Palette.GOLD
		bw = 4
	elif enabled:
		border = _accent
	add_theme_stylebox_override("panel", Palette.box(_bg, border, 12, bw, 10))
	modulate = Color(1, 1, 1, 1) if enabled or highlighted or not dim_when_disabled else Color(0.75, 0.75, 0.8, 0.6)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_press_pos = event.global_position
		elif _pressed:
			_pressed = false
			if event.global_position.distance_to(_press_pos) < TAP_SLOP:
				tapped.emit()

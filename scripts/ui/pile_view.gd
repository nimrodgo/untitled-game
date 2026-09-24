class_name PileView
extends DropTarget
## Your deck, drawn as a small stack of card backs with a count.
## Tap to view your cards; it's also where bought cards are dropped.

signal tapped

var _count_label: Label
var _sub_label: Label
var _backs: Array[Panel] = []
var _pressed := false
var _press_pos := Vector2.ZERO


func _init() -> void:
	custom_minimum_size = Vector2(112, 150)
	bg_color = Palette.ABYSS
	mouse_filter = Control.MOUSE_FILTER_STOP
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2(90, 128)
	add_child(holder)
	for i in 3:
		var p := Panel.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.size = Vector2(70, 96)
		p.position = Vector2(10 + i * 4, 4 + i * 4)
		var sb := Palette.box(Palette.CARD.darkened(0.25), Palette.TEAL, 8, 2, 0)
		p.add_theme_stylebox_override("panel", sb)
		holder.add_child(p)
		_backs.append(p)
		# inner frame for a card-back look
		var inner := Panel.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.position = Vector2(9, 9)
		inner.size = Vector2(52, 78)
		inner.add_theme_stylebox_override("panel", Palette.box(Color.TRANSPARENT, Palette.TEAL.darkened(0.3), 5, 2, 0))
		p.add_child(inner)
	_count_label = CardView._label("0", 32, Palette.FOAM)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.position = Vector2(18, 22)
	_count_label.size = Vector2(70, 60)
	_count_label.add_theme_color_override("font_outline_color", Palette.ABYSS)
	_count_label.add_theme_constant_override("outline_size", 8)
	holder.add_child(_count_label)
	_sub_label = CardView._label("", 13, Palette.MUTED)
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.position = Vector2(0, 108)
	_sub_label.size = Vector2(90, 20)
	holder.add_child(_sub_label)


func set_counts(draw: int, discard: int) -> void:
	_count_label.text = str(draw)
	_sub_label.text = "discard %d" % discard
	for i in _backs.size():
		_backs[i].visible = draw > i or i == 0


func target_center() -> Vector2:
	return _backs[_backs.size() - 1].get_global_rect().get_center()


func pulse() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.12, 1.12), 0.1)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_press_pos = event.global_position
		elif _pressed:
			_pressed = false
			if event.global_position.distance_to(_press_pos) < CardView.TAP_SLOP:
				tapped.emit()

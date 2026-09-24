class_name HandView
extends Control
## Fanned hand of cards. Tap a card to inspect it; drag it into `drop_zone`
## to play it. Works with mouse and touch (touch is emulated as mouse).

signal card_tapped(card: Variant)
signal card_dropped(card: Variant)
signal dragging_changed(is_dragging: bool)

const DRAG_START := 14.0

var drop_zone: Control
var _views: Array[CardView] = []
var _drag_view: CardView
var _dragging := false
var _press_pos := Vector2.ZERO
var _grab_offset := Vector2.ZERO


func _ready() -> void:
	resized.connect(_layout.bind(false))


func set_views(views: Array[CardView]) -> void:
	for v in _views:
		remove_child(v)
		v.queue_free()
	_views = views
	_drag_view = null
	_dragging = false
	for v in _views:
		add_child(v)
		v.gui_input.connect(_on_view_input.bind(v))
		v.tapped.connect(_on_view_tapped.bind(v))
	_layout(false)
	# Autowrapped labels only know their height after the first layout pass.
	_layout.call_deferred(false)


func is_over_drop_zone(global_pos: Vector2) -> bool:
	return drop_zone != null and drop_zone.get_global_rect().has_point(global_pos)


func _layout(animate: bool) -> void:
	var n := _views.size()
	if n == 0:
		return
	var w := CardView.HAND.x
	var h := CardView.HAND.y
	var avail := size.x
	var step := minf(w + 8.0, (avail - w) / maxf(1.0, n - 1.0))
	var total := step * (n - 1) + w
	var x0 := (avail - total) * 0.5
	var mid := (n - 1) * 0.5
	for i in n:
		var v := _views[i]
		var t := i - mid
		var target_pos := Vector2(x0 + step * i, 4.0 + t * t * 2.5)
		var target_rot := t * 0.045 if n > 1 else 0.0
		v.size = CardView.HAND
		v.pivot_offset = Vector2(w * 0.5, h)
		v.z_index = i
		if animate:
			var tw := v.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(v, "position", target_pos, 0.18)
			tw.tween_property(v, "rotation", target_rot, 0.18)
			tw.tween_property(v, "scale", Vector2.ONE, 0.18)
		else:
			v.position = target_pos
			v.rotation = target_rot
			v.scale = Vector2.ONE


func _on_view_input(event: InputEvent, v: CardView) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_view = v
			_press_pos = event.global_position
			_dragging = false
		elif _drag_view == v:
			if _dragging:
				_end_drag(event.global_position)
			_drag_view = null
	elif event is InputEventMouseMotion and _drag_view == v:
		if not _dragging and v.enabled and event.global_position.distance_to(_press_pos) > DRAG_START:
			_dragging = true
			v._pressed = false   # cancel the tap
			v.rotation = 0.0
			v.z_index = 100
			v.scale = Vector2(1.08, 1.08)
			_grab_offset = v.global_position - event.global_position
			dragging_changed.emit(true)
		if _dragging:
			v.global_position = event.global_position + _grab_offset


func _end_drag(pos: Vector2) -> void:
	var v := _drag_view
	_dragging = false
	dragging_changed.emit(false)
	var dropped := is_over_drop_zone(pos)
	if dropped:
		# Deferred: playing rebuilds the hand, which frees this view mid-input.
		card_dropped.emit.call_deferred(v.payload)
	else:
		_layout(true)


## Taps are forwarded from the CardViews.
func _on_view_tapped(v: CardView) -> void:
	card_tapped.emit(v.payload)

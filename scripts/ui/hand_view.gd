class_name HandView
extends Control
## Fanned hand of cards. Tap a card to inspect it; drag it out of the hand
## (release anywhere outside this area) to play it. Works with mouse and touch
## (touch is emulated as mouse).
##
## Visual language: while dragging, the card grows and glows gold as soon as
## releasing would play it. Newly drawn cards fly in from `spawn_point`.

signal card_tapped(card: Variant)
## `at_global` is the centre of the card where it was released.
signal card_dropped(card: Variant, at_global: Vector2)
signal dragging_changed(is_dragging: bool)

const DRAG_START := 14.0
## How far outside the hand area (px) the pointer must be to count as "out".
const RELEASE_MARGIN := 12.0

## Global position new cards fly in from (e.g. the deck). INF = no animation.
var spawn_point := Vector2.INF

var _views: Array[CardView] = []
var _known_uids := {}
var _drag_view: CardView
var _dragging := false
var _would_play := false
var _press_pos := Vector2.ZERO
var _grab_offset := Vector2.ZERO


func _ready() -> void:
	resized.connect(_layout.bind(false, []))


func set_views(views: Array[CardView]) -> void:
	for v in _views:
		remove_child(v)
		v.queue_free()
	_views = views
	_drag_view = null
	_dragging = false
	var fresh: Array[CardView] = []
	var uids := {}
	for v in _views:
		add_child(v)
		v.gui_input.connect(_on_view_input.bind(v))
		v.tapped.connect(func(): card_tapped.emit(v.payload))
		var uid: int = v.payload.uid if v.payload is CardInstance else -1
		uids[uid] = true
		if not _known_uids.has(uid) and spawn_point != Vector2.INF:
			fresh.append(v)
	_known_uids = uids
	_layout(false, fresh)
	# Autowrapped labels only know their height after the first layout pass.
	_layout.call_deferred(false, [])


func is_outside_hand(global_pos: Vector2) -> bool:
	return not get_global_rect().grow(RELEASE_MARGIN).has_point(global_pos)


func _layout(animate: bool, fresh: Array) -> void:
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
	var fresh_i := 0
	for i in n:
		var v := _views[i]
		if not is_instance_valid(v):
			continue
		v.size = CardView.HAND   # re-apply: autowrapped text may have inflated it
		if v.has_meta("flying") or (v == _drag_view and _dragging):
			continue
		var t := i - mid
		var target_pos := Vector2(x0 + step * i, 4.0 + t * t * 2.5)
		var target_rot := t * 0.045 if n > 1 else 0.0
		v.size = CardView.HAND
		v.pivot_offset = Vector2(w * 0.5, h)
		v.z_index = i
		if fresh.has(v):
			# Deal in from the deck.
			v.set_meta("flying", true)
			v.global_position = spawn_point - v.size * 0.5
			v.scale = Vector2(0.3, 0.3)
			v.rotation = 0.0
			var tw := v.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			var delay := fresh_i * 0.07
			tw.tween_property(v, "position", target_pos, 0.35).set_delay(delay)
			tw.tween_property(v, "rotation", target_rot, 0.35).set_delay(delay)
			tw.tween_property(v, "scale", Vector2.ONE, 0.35).set_delay(delay)
			tw.chain().tween_callback(func(): if is_instance_valid(v): v.remove_meta("flying"))
			fresh_i += 1
		elif animate:
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
			v.remove_meta("flying")
			v.rotation = 0.0
			v.z_index = 100
			v.pivot_offset = v.size * 0.5
			v.scale = Vector2(1.05, 1.05)
			_grab_offset = v.global_position - event.global_position
			dragging_changed.emit(true)
		if _dragging:
			v.global_position = event.global_position + _grab_offset
			var wp := is_outside_hand(event.global_position)
			if wp != _would_play:
				_would_play = wp
				v.set_highlighted(wp)
				var tw := v.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(v, "scale", Vector2(1.18, 1.18) if wp else Vector2(1.05, 1.05), 0.12)


func _end_drag(pos: Vector2) -> void:
	var v := _drag_view
	_dragging = false
	var dropped := _would_play and is_outside_hand(pos)
	_would_play = false
	dragging_changed.emit(false)
	if dropped:
		# Deferred: playing rebuilds the hand, which frees this view mid-input.
		card_dropped.emit.call_deferred(v.payload, v.get_global_rect().get_center())
	else:
		v.set_highlighted(false)
		_layout(true, [])


## Global centre of the card view showing `card`, if it's in the hand.
func card_center(card: Variant) -> Vector2:
	for v in _views:
		if is_instance_valid(v) and v.payload == card:
			return v.get_global_rect().get_center()
	return Vector2.INF

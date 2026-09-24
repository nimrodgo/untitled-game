class_name Fx
extends RefCounted
## Small reusable UI animations.


## Floating "+1 🪙" style text that rises and fades.
static func float_text(layer: Control, at_global: Vector2, bbcode: String, font_size := 28) -> void:
	var r := Icons.rich_label("[center]" + bbcode + "[/center]", font_size, Palette.FOAM)
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.custom_minimum_size = Vector2(160, 0)
	r.add_theme_color_override("font_outline_color", Palette.ABYSS)
	r.add_theme_constant_override("outline_size", 8)
	layer.add_child(r)
	r.global_position = at_global - Vector2(80, font_size * 0.7)
	var tw := r.create_tween().set_parallel()
	tw.tween_property(r, "global_position:y", r.global_position.y - 56, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(r, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tw.chain().tween_callback(r.queue_free)


## Moves a view (already in `layer`) so its centre lands on `to_global`,
## shrinking and fading, then frees it and calls `done`.
static func fly_into(view: Control, to_global: Vector2, done: Callable = Callable(), dur := 0.45) -> void:
	view.pivot_offset = view.size * 0.5
	var tw := view.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(view, "global_position", to_global - view.size * 0.5, dur)
	tw.tween_property(view, "scale", Vector2(0.2, 0.2), dur)
	tw.tween_property(view, "modulate:a", 0.3, dur)
	tw.chain().tween_callback(func():
		view.queue_free()
		if done.is_valid():
			done.call())


## "Card played": the card pops to `center_global`, grows, glows and fades.
static func resolve(view: Control, center_global: Vector2) -> void:
	view.pivot_offset = view.size * 0.5
	view.z_index = 300
	var tw := view.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_parallel()
	tw.tween_property(view, "global_position", center_global - view.size * 0.5, 0.22)
	tw.tween_property(view, "scale", Vector2(1.35, 1.35), 0.22)
	tw.tween_property(view, "rotation", 0.0, 0.22)
	tw.chain().tween_property(view, "modulate", Color(1.6, 1.5, 1.0, 1.0), 0.12)
	tw.chain().set_parallel()
	tw.tween_property(view, "scale", Vector2(1.6, 1.6), 0.3)
	tw.tween_property(view, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(view.queue_free)


## Quick horizontal shake (e.g. "can't do that").
static func shake(node: Control) -> void:
	var x := node.position.x
	var tw := node.create_tween()
	for d in [8.0, -8.0, 5.0, -5.0, 0.0]:
		tw.tween_property(node, "position:x", x + d, 0.04)

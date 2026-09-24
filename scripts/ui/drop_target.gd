class_name DropTarget
extends PanelContainer
## A panel that can light up as a drag-and-drop target.
## IDLE = normal, ACTIVE = "you can drop here" (pulses), HOVER = "release now".

enum State { IDLE, ACTIVE, HOVER }

var bg_color: Color = Palette.PANEL
var accent: Color = Palette.TEAL
var radius := 14
var state: State = State.IDLE
var _pulse: Tween


func _ready() -> void:
	_restyle()
	resized.connect(func(): pivot_offset = size * 0.5)


func set_state(s: State) -> void:
	if s == state:
		return
	state = s
	_restyle()
	if _pulse:
		_pulse.kill()
		_pulse = null
	self_modulate = Color.WHITE
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.06, 1.06) if s == State.HOVER else Vector2.ONE, 0.15)
	if s == State.ACTIVE:
		_pulse = create_tween().set_loops()
		_pulse.tween_property(self, "self_modulate", Color(1.35, 1.35, 1.35), 0.45)
		_pulse.tween_property(self, "self_modulate", Color.WHITE, 0.45)


func contains_global(p: Vector2) -> bool:
	return is_visible_in_tree() and get_global_rect().has_point(p)


func _restyle() -> void:
	match state:
		State.IDLE:
			add_theme_stylebox_override("panel", Palette.box(bg_color, accent.darkened(0.55), radius, 2, 10))
		State.ACTIVE:
			add_theme_stylebox_override("panel", Palette.box(bg_color.lerp(accent, 0.15), accent, radius, 3, 10))
		State.HOVER:
			add_theme_stylebox_override("panel", Palette.box(bg_color.lerp(Palette.GOLD, 0.2), Palette.GOLD, radius, 4, 10))

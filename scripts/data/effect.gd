class_name Effect
extends Resource
## Base class for every effect primitive. Cards, items, trinkets and
## enhancements are just lists of these. Add a new primitive by extending
## this class and overriding apply / describe / ai_score.

@export var target: GameRules.Target = GameRules.Target.SELF


func apply(_ctx: EffectContext) -> void:
	pass


## Short human-readable text shown on cards.
func describe() -> String:
	return "(effect)"


## Rough value for the AI, from the owner's point of view. Positive = good.
func ai_score() -> float:
	return 0.0


## When true, descriptions are phrased for an enemy intent ("You lose 2 coins").
var enemy_voice := false


func _who() -> String:
	if enemy_voice:
		return "Enemy " if target == GameRules.Target.SELF else "You: "
	return "" if target == GameRules.Target.SELF else "Opponent "


static func describe_list(effects: Array, from_enemy := false) -> String:
	var parts: PackedStringArray = []
	for e in effects:
		if e:
			e.enemy_voice = from_enemy
			parts.append(e.describe())
	return ". ".join(parts)


static func score_list(effects: Array) -> float:
	var s := 0.0
	for e in effects:
		if e:
			s += e.ai_score()
	return s

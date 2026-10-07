class_name Effect
extends Resource
## Base class for every effect primitive. Cards, items, trinkets and
## enhancements are just lists of these. Add a new primitive by extending
## this class and overriding apply / describe / ai_score.

@export var target: GameRules.Target = GameRules.Target.SELF


## May be a coroutine (effects that ask the player something `await`).
func apply(_ctx: EffectContext) -> void:
	pass


## Costs: return false when this effect can't be paid right now; the card
## (or trinket) is then unplayable. Most effects are always payable.
func can_pay(_ctx: EffectContext) -> bool:
	return true


## True for costs ("Pay 2", "Discard 1", "Pass", "Destroy this"): the
## generated text puts a ➡ after them instead of a full stop.
func is_cost() -> bool:
	return false


## Short human-readable text shown on cards.
func describe() -> String:
	return "(effect)"


## Coins this effect would give its owner if the card were played right now,
## shown on cards as {gain}. `card` is null for a market card. Default 0.
func preview_coins(_enc: Encounter, _owner: PlayerState, _cd: CardData, _card: CardInstance) -> int:
	return 0


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
	var out := ""
	var prev_cost := false
	for e in effects:
		if not e:
			continue
		e.enemy_voice = from_enemy
		if out != "":
			out += " ➡ " if prev_cost else ". "
		out += e.describe()
		prev_cost = e.is_cost()
	return out


static func score_list(effects: Array) -> float:
	var s := 0.0
	for e in effects:
		if e:
			s += e.ai_score()
	return s

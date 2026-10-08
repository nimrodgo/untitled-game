class_name CancelEnemyActionEffect
extends Effect
## "Cancel the enemy's next action this turn": the opponent doesn't answer your
## next `amount` normal actions this turn. Each skipped answer still uses up its
## intent (the cycle moves on) and one of the enemy's actions this round.
## Unused cancels end with the turn.

@export var amount: int = 1


func apply(ctx: EffectContext) -> void:
	ctx.owner.cancel_opponent_actions += amount
	ctx.encounter.log_line("  The enemy's next action is cancelled.")


func describe() -> String:
	if amount == 1:
		return "Cancel the enemy's next action this turn"
	return "Cancel the enemy's next %d actions this turn" % amount


func ai_score() -> float:
	return 1.5 * amount

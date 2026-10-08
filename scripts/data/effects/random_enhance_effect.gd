class_name RandomEnhanceEffect
extends Effect
## Attach a random enhancement to this card (the one bought / played): any
## enhancement in the game except ones that only destroy the card (Fleeting).
## Respects the card's enhancement limit (Blank Slate has none).

func apply(ctx: EffectContext) -> void:
	var c := ctx.card
	if c == null or not (c.enhancements.is_empty() or c.data.unlimited_enhancements):
		return
	var pool: Array = ContentLibrary.enhancements().filter(func(e: EnhancementData): return not e.destroy_on_apply)
	if pool.is_empty():
		return
	var e: EnhancementData = pool[ctx.encounter.rng.randi_range(0, pool.size() - 1)]
	c.add_enhancement(e)
	ctx.encounter.log_line("  %s is enhanced with %s." % [c.get_name(), e.display_name])


func describe() -> String:
	return "Randomly enhance this"


func ai_score() -> float:
	return 1.5

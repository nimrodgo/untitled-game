class_name ChooseOneEffect
extends Effect
## "X OR Y": the owner picks one option. Options whose costs can't be paid
## are unavailable; if none can be paid the card can't be played.

@export var options: Array[EffectOption] = []


func can_pay(ctx: EffectContext) -> bool:
	for o in options:
		if o and o.can_pay(ctx):
			return true
	return options.is_empty()


func apply(ctx: EffectContext) -> void:
	if options.is_empty():
		return
	var req := ChoiceRequest.new()
	req.kind = ChoiceRequest.Kind.OPTIONS
	req.verb = "Choose"
	req.source_name = ctx.source_name
	req.source_card = ctx.card
	for o in options:
		req.candidates.append(o.get_label())
		req.enabled.append(o.can_pay(ctx))
	var picks: Array = await ctx.encounter.request_choice(req)
	var chosen: EffectOption = options[picks[0]]
	ctx.encounter.log_line("  %s choose: %s." % [ctx.owner.display_name, Icons.plain(chosen.get_label())])
	await ctx.encounter.run_effects(chosen.effects, ctx)


func describe() -> String:
	var parts: PackedStringArray = []
	for o in options:
		if o:
			parts.append(o.get_label())
	return " OR ".join(parts)


func ai_score() -> float:
	var best := 0.0
	for o in options:
		if o:
			best = maxf(best, Effect.score_list(o.effects))
	return best

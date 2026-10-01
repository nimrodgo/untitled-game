class_name RefreshTrinketsEffect
extends Effect
## Make used trinkets usable again this turn: `amount` of your choice, or all.

@export var amount: int = 1
@export var all: bool = false


func apply(ctx: EffectContext) -> void:
	var p := ctx.owner
	var used: Array = []
	for i in p.trinkets.size():
		if p.trinkets[i].used:
			used.append(i)
	var picks: Array = used
	if not all and used.size() > amount:
		var req := ChoiceRequest.new()
		req.kind = ChoiceRequest.Kind.TRINKET
		req.verb = "Refresh"
		req.candidates = used
		req.min_count = amount
		req.max_count = amount
		req.source_name = ctx.source_name
		req.source_card = ctx.card
		picks = await ctx.encounter.request_choice(req)
	for i in picks:
		p.trinkets[i].used = false
		ctx.encounter.log_line("  %s refresh %s." % [p.display_name, p.trinkets[i].get_name()])


func describe() -> String:
	if all:
		return "↺ all trinkets"
	return "↺ a trinket" if amount == 1 else "↺ %d trinkets" % amount


func ai_score() -> float:
	return 1.0 * amount

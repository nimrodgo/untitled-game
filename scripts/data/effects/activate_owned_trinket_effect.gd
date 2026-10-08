class_name ActivateOwnedTrinketEffect
extends Effect
## Choose a trinket you own and resolve its level-N effect (its highest level
## if it has fewer), whatever level yours is. It doesn't use the trinket up:
## a used trinket can be picked, and an unused one stays usable.

@export var level: int = 3


func apply(ctx: EffectContext) -> void:
	var enc := ctx.encounter
	var p := ctx.owner
	var req := ChoiceRequest.new()
	req.kind = ChoiceRequest.Kind.TRINKET
	req.verb = "Activate"
	req.trinket_level = level
	req.source_name = ctx.source_name
	req.source_card = ctx.card
	for i in p.trinkets.size():
		if not p.trinkets[i].data.levels.is_empty():
			req.candidates.append(i)
	var picks: Array = await enc.request_choice(req)
	for idx in picks:
		var td: TrinketData = p.trinkets[idx].data
		var lv_num := mini(level, td.levels.size())
		enc.log_line("  %s activate %s (level %d)." % [p.display_name, td.display_name, lv_num])
		var tctx := EffectContext.new()
		tctx.encounter = enc
		tctx.owner = p
		tctx.opponent = ctx.opponent
		tctx.source_name = td.display_name
		await enc.run_effects(td.levels[lv_num - 1].effects, tctx)
		ctx.pass_after = ctx.pass_after or tctx.pass_after
		ctx.grant_extra_action = ctx.grant_extra_action or tctx.grant_extra_action


func describe() -> String:
	return "Use the level %d effect of a trinket you own" % level


func ai_score() -> float:
	return 2.0

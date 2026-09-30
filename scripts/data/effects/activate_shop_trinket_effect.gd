class_name ActivateShopTrinketEffect
extends Effect
## Choose a trinket in the market and resolve its level-N effect (its
## highest level if it has fewer). The trinket stays in the market.

@export var level: int = 3


func apply(ctx: EffectContext) -> void:
	var enc := ctx.encounter
	var req := ChoiceRequest.new()
	req.kind = ChoiceRequest.Kind.SHOP_TRINKET
	req.verb = "Activate"
	req.source_name = ctx.source_name
	req.source_card = ctx.card
	for i in enc.shop.trinkets.size():
		var td: TrinketData = enc.shop.trinkets[i]
		if td and not td.levels.is_empty():
			req.candidates.append(i)
	var picks: Array = await enc.request_choice(req)
	for slot in picks:
		var td: TrinketData = enc.shop.trinkets[slot]
		var lv: TrinketLevel = td.levels[mini(level, td.levels.size()) - 1]
		enc.log_line("  %s activate %s (level %d)." % [ctx.owner.display_name, td.display_name, mini(level, td.levels.size())])
		var tctx := EffectContext.new()
		tctx.encounter = enc
		tctx.owner = ctx.owner
		tctx.opponent = ctx.opponent
		tctx.source_name = td.display_name
		await enc.run_effects(lv.effects, tctx)
		ctx.pass_after = ctx.pass_after or tctx.pass_after


func describe() -> String:
	return "Activate the level %d effect of a trinket in the shop" % level


func ai_score() -> float:
	return 2.0

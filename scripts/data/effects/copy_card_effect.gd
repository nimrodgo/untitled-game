class_name CopyCardEffect
extends Effect
## Pick `amount` different cards in your hand (fewer if you have fewer) and
## make `copies` copies of each, temporary (⏳) by default. Copies are the
## plain card (no enhancements other than Temporary).
## `discard_original`: discard each picked card first ("⤵ a card ➡ a copy").
## `bonus_coins`: gained once if anything was copied.

@export var amount: int = 1
@export var copies: int = 1
@export var zone: GameRules.Zone = GameRules.Zone.HAND
@export var temporary: bool = true
@export var discard_original: bool = false
@export var bonus_coins: int = 0


func apply(ctx: EffectContext) -> void:
	var enc := ctx.encounter
	var p := ctx.owner
	var picks: Array = await enc.choose_cards(p, GameRules.PILE_HAND, amount,
		"Discard" if discard_original else "Copy", ctx, false, Callable(), ctx.card)
	if picks.is_empty():
		return
	var datas: Array = []
	for c in picks:
		datas.append(c.data)
	if discard_original:
		await enc.discard_cards(p, picks)
	for cd in datas:
		for i in copies:
			await enc.add_card(p, cd, zone, temporary, p)
	if bonus_coins > 0:
		enc.change_coins(p, bonus_coins, ctx.source_name)


func describe() -> String:
	var t := "⏳ " if temporary else ""
	var s := ""
	var what := "a card" if amount == 1 else "%d cards" % amount
	if copies == 1:
		s = "a %scopy of %s in your hand" % [t, what]
	else:
		s = "%d %scopies of %s in your hand" % [copies, t, what]
	if discard_original:
		s = "⤵ a card ➡ " + s.replace("of a card in your hand", "of it")
	else:
		s = "Make " + s
	if bonus_coins > 0:
		s += ". " + Icons.coins(bonus_coins)
	return _who() + s


func ai_score() -> float:
	return 0.8 * amount * copies + bonus_coins - (0.3 if discard_original else 0.0)

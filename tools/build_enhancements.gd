extends SceneTree
## Writes one enhancement per card set into content/test/enhancements/.
## Run:  godot --headless --path . --script res://tools/build_enhancements.gd
## Source of truth for the effects: the "Card set enhancements" doc (Nimrod's table).
## Names and prices are placeholders. Each has a corner icon (EnhancementData.icon).

const DIR := "res://content/test/enhancements/"
const PLACEHOLDER_COST := 3


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	# Coins: 🪙🪙 (+2 coins on play)
	var gain := GainCoinsEffect.new()
	gain.amount = 2
	var e := _make("gilded", "Gilded", CardSets.Id.COINS)
	e.icon = "🪙"
	e.extra_on_play.assign([gain])
	_save(e)

	# Draw: 🂠 (draw a card on play)
	var draw := DrawCardsEffect.new()
	e = _make("insight", "Insight", CardSets.Id.DRAW)
	e.icon = "🂠"
	e.extra_on_play.assign([draw])
	_save(e)

	# Discard: When this is ⤵, 🂠 it
	e = _make("boomerang", "Boomerang", CardSets.Id.DISCARD)
	e.icon = "⤵"
	e.on_discard.assign([DrawThisCardEffect.new()])
	e.description = "When this is ⤵, 🂠 it"
	_save(e)

	# Trim: This card is immediately 🔥 (the moment you buy it, not when played)
	e = _make("fleeting", "Fleeting", CardSets.Id.TRIM)
	e.icon = "🔥"
	e.destroy_on_apply = true
	e.description = "This card is immediately 🔥"
	_save(e)

	# Retain: This card is 📌 while in your hand
	e = _make("anchored", "Anchored", CardSets.Id.RETAIN)
	e.icon = "📌"
	e.retain = true
	e.description = "This card is 📌 while in your hand"
	_save(e)

	# Utility: This card effect is ⚡
	e = _make("hasty", "Hasty", CardSets.Id.UTILITY)
	e.icon = "⚡"
	e.make_instant = true
	e.description = "This card effect is ⚡"
	_save(e)

	# Market: When you play this card, add a copy to your deck
	e = _make("franchise", "Franchise", CardSets.Id.MARKET)
	e.icon = "⧉"
	e.extra_on_play.assign([AddCopyOfThisCardEffect.new()])
	e.description = "When you play this card, add a copy to your deck"
	_save(e)

	# Curse Synergy: This card is considered a curse
	e = _make("tainted", "Tainted", CardSets.Id.CURSE_SYNERGY)
	e.icon = "☠"
	e.counts_as_curse = true
	e.description = "This card is considered a curse"
	_save(e)

	quit()


func _make(id: String, title: String, set_id: CardSets.Id) -> EnhancementData:
	var e := EnhancementData.new()
	e.id = StringName(id)
	e.display_name = title
	e.cost = PLACEHOLDER_COST
	e.card_set = set_id
	return e


func _save(e: EnhancementData) -> void:
	var path := DIR + "%s.tres" % e.id
	var err := ResourceSaver.save(e, path)
	if err != OK:
		push_error("Failed to save %s: %s" % [path, err])
	print("saved ", path)

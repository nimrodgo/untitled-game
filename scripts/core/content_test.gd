extends RefCounted
## (No class_name: encounter_screen.gd preloads it as ContentTest.)
## Test runs started from the editor's Content tab (its "Play test" / "Test this"
## buttons). The tab writes PATH and runs the main scene; the encounter screen then
## plays the chosen encounter and adds the chosen pieces on top of the normal loadout.
##
## The file is read once and deleted, and the test is kept in memory so "Play again"
## repeats it. A normal run (F5) has no file, so nothing changes. Debug builds only.
##
## File format (JSON): {
##   "cards": [{"path", "count"}], "charms": [path], "trinkets": [{"path", "level"}],
##   "enhancements": [path], "enemy_charms": [path],
##   "encounter": path or "", "enemy": path or "",
##   "start_with": bool,   # add the cards / charms / trinkets to the loadout
##   "opening_hand": bool, # test cards (and enhanced ones) are in the first hand
##   "market": bool,       # round 1's market starts with the test pieces in it
##   "coins": int,         # extra starting coins
##   "summary": String }   # shown on screen

const PATH := "user://content_test.json"

static var active := {}


## Reads (and deletes) a test written by the Content tab, if there is one.
static func load_pending() -> void:
	if not OS.is_debug_build() or not FileAccess.file_exists(PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	active = parsed if parsed is Dictionary else {}


static func is_active() -> bool:
	return not active.is_empty()


## The encounter to play: the test's (with its enemy swapped in), else `fallback`.
static func encounter(fallback: EncounterData) -> EncounterData:
	var out := fallback
	var p := String(active.get("encounter", ""))
	if p != "" and ResourceLoader.exists(p):
		out = load(p)
	var ep := String(active.get("enemy", ""))
	if ep != "" and ResourceLoader.exists(ep) and out:
		out = out.duplicate()
		out.enemy = load(ep)
	return out


## A copy of `base` with the test's cards, charms, trinkets and coins added.
static func loadout(base: LoadoutData) -> LoadoutData:
	var lo := LoadoutData.new()
	lo.starting_deck = base.starting_deck.duplicate()
	lo.charms = base.charms.duplicate()
	lo.trinkets = base.trinkets.duplicate()
	lo.starting_coins = base.starting_coins + int(active.get("coins", 0))
	if not active.get("start_with", true):
		return lo
	for c in _cards():
		for i in int(c["count"]):
			lo.starting_deck.append(c["data"])
	for d in _list("charms"):
		lo.charms.append(d)
	for t in _trinkets():
		lo.trinkets.append(t["data"])
	return lo


## Encounter.on_setup: runs after the market is stocked and the deck shuffled,
## before the first hand is drawn.
static func setup(enc: Encounter) -> void:
	var p := enc.player
	if active.get("start_with", true):
		# Trinket levels.
		for t in _trinkets():
			for inst in p.trinkets:
				if inst.data == t["data"] and inst.level == 0:
					inst.level = clampi(int(t["level"]) - 1, 0, maxi(0, inst.data.levels.size() - 1))
					break
	# The test copies of each card (the last ones of that card in the deck).
	var picked: Array = []
	if active.get("start_with", true):
		for c in _cards():
			var left := int(c["count"])
			for i in range(p.draw_pile.size() - 1, -1, -1):
				if left <= 0:
					break
				var inst: CardInstance = p.draw_pile[i]
				if inst.data == c["data"] and not picked.has(inst):
					picked.append(inst)
					left -= 1
	# Enhancements go on the test cards, or on a random starting card if there are none.
	var enh := _list("enhancements")
	if not enh.is_empty():
		var targets: Array = picked.duplicate()
		if targets.is_empty():
			var playable := p.draw_pile.filter(func(ci: CardInstance): return ci.data.playable)
			if not playable.is_empty():
				targets.append(playable[enc.rng.randi_range(0, playable.size() - 1)])
		for ci in targets:
			for e in enh:
				ci.add_enhancement(e)
			if not picked.has(ci):
				picked.append(ci)
	# Opening hand: move them to the top of the deck (drawn from the back).
	if active.get("opening_hand", true):
		for ci in picked.slice(0, GameRules.HAND_SIZE):
			p.draw_pile.erase(ci)
			p.draw_pile.append(ci)
	for d in _list("enemy_charms"):
		enc.enemy.charms.append(CharmInstance.new(d))
	if active.get("market", false):
		var cards := _cards()
		for i in mini(cards.size(), enc.shop.cards.size()):
			enc.shop.cards[i] = cards[i]["data"]
		var charms := _list("charms")
		for i in mini(charms.size(), enc.shop.charms.size()):
			enc.shop.charms[i] = charms[i]
		var trinkets := _trinkets()
		for i in mini(trinkets.size(), enc.shop.trinkets.size()):
			enc.shop.trinkets[i] = trinkets[i]["data"]
		for i in mini(enh.size(), enc.shop.enhancements.size()):
			enc.shop.enhancements[i] = enh[i]
	enc.log_line("[b]Test run:[/b] " + summary())


static func summary() -> String:
	return String(active.get("summary", ""))


static func _load(path) -> Resource:
	var s := String(path)
	return load(s) if s != "" and ResourceLoader.exists(s) else null


static func _list(key: String) -> Array:
	var out := []
	for path in active.get(key, []):
		var r := _load(path)
		if r:
			out.append(r)
	return out


static func _cards() -> Array:
	var out := []
	for c in active.get("cards", []):
		var r := _load(c.get("path", ""))
		if r is CardData:
			out.append({"data": r, "count": maxi(1, int(c.get("count", 1)))})
	return out


static func _trinkets() -> Array:
	var out := []
	for t in active.get("trinkets", []):
		var r := _load(t.get("path", ""))
		if r is TrinketData:
			out.append({"data": r, "level": maxi(1, int(t.get("level", 1)))})
	return out

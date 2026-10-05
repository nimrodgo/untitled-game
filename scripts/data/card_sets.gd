class_name CardSets
extends RefCounted
## Card sets: every card, item and trinket belongs to exactly one set, grouped
## by mechanic. Sets have no gameplay effect (yet); for now they only tint the
## tile. Names and colors are placeholders.
##
## The numbers are stored in the .tres files, so only ever APPEND new ids.

enum Id {
	NONE,
	CURSES,        ## The curses themselves.
	COINS,         ## Simple cards that want more and more coins.
	DRAW,          ## Drawing, fetching from the deck, draw synergy.
	DISCARD,       ## Discarding and discard payoffs.
	TRIM,          ## Remove and destroy.
	RETAIN,        ## Keeping cards in hand between turns.
	UTILITY,       ## Unique effects (replays, trinket refresh, extra turns...).
	MARKET,        ## Market manipulation: buying, restocking, recovering cards.
	CURSE_SYNERGY, ## Gaining, moving and cashing in curses.
}

const _INFO := {
	Id.NONE: ["No set", Color("000000")],
	Id.CURSES: ["Curses", Color("4a1f33")],
	Id.COINS: ["Coins", Color("7a6212")],
	Id.DRAW: ["Draw", Color("11587a")],
	Id.DISCARD: ["Discard", Color("8a4a2a")],
	Id.TRIM: ["Trim", Color("8a2f3a")],
	Id.RETAIN: ["Retain", Color("3a7a2a")],
	Id.UTILITY: ["Utility", Color("4a5568")],
	Id.MARKET: ["Market", Color("0f6b6b")],
	Id.CURSE_SYNERGY: ["Curse Synergy", Color("7a2f6a")],
}


## Sold in every encounter that lists its card sets (see EncounterData.card_sets).
const ALWAYS_SOLD: Array[Id] = [Id.UTILITY, Id.COINS]


static func display_name(id: Id) -> String:
	return _INFO[id][0]


static func color(id: Id) -> Color:
	return _INFO[id][1]

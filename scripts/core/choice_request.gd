class_name ChoiceRequest
extends RefCounted
## A decision the player has to make while an effect resolves (pick cards,
## pick one of several options, a market card, a trinket...).
## Effects create one and `await ctx.encounter.request_choice(req)`.
## The answer is an Array of the chosen `candidates` (OPTIONS: an Array with
## the chosen option index).

enum Kind {
	CARDS,          ## candidates: CardInstance (see `piles` for where they are)
	OPTIONS,        ## candidates: String labels; `enabled` says which can be picked
	SHOP_CARD,      ## candidates: market slot indices (int)
	SHOP_TRINKET,   ## candidates: market trinket slot indices (int)
	TRINKET,        ## candidates: indices into player.trinkets
	CARD_DATA,      ## candidates: CardInstance NOT in your piles (removed / destroyed lists)
}

var kind: Kind = Kind.CARDS
## Short verb shown to the player, e.g. "Discard", "Destroy", "Retain".
var verb: String = ""
var candidates: Array = []
## OPTIONS only: whether each option can be chosen.
var enabled: Array = []
var min_count := 1
var max_count := 1
## Where the source effect came from (card / charm / trinket name) for the UI.
var source_name := ""
## The card being played, if any (the UI shows it next to the picker).
var source_card: CardInstance
## CARDS: true when every candidate is in the hand (the UI picks in place).
var hand_only := false
## CARDS: show candidates in the given order (e.g. "look at the top 3").
## Otherwise the draw pile is shown sorted so the order isn't revealed.
var ordered := false
## Optional per-candidate labels for the picker (e.g. "Deck", "Discard").
var groups: Array = []
## TRINKET: show this level's text for each trinket (1 = level 1...; 0 = its
## current level).
var trinket_level := 0


func is_optional() -> bool:
	return min_count == 0

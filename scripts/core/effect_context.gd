class_name EffectContext
extends RefCounted
## Everything an effect needs to know when it resolves.

var encounter: Encounter
var owner: PlayerState          ## Whoever owns the card/charm/trinket.
var opponent: PlayerState
var card: CardInstance          ## The card involved, if any (may be null).
var source_name: String = ""    ## For the log.

## Mutable results effects can set:
var buy_destination: GameRules.Zone = GameRules.DEFAULT_BUY_DESTINATION
var grant_extra_action := false
## Set by PassEffect: the owner's turn ends right after this action (the enemy doesn't answer it).
var pass_after := false
## True while the start-of-turn hand is being drawn.
var opening_draw := false
## A charm effect set this when the player declined an optional ability, so
## the charm isn't marked as used.
var declined := false
## The pile a card came from (GameRules.PILE_*), for trash triggers.
var from_pile := 0
## "🂠 this" on a card's on-buy: the bought card is drawn (counts as a draw;
## if you can't draw it goes where it normally would).
var buy_draw := false
## Set by a cost effect that couldn't be paid in full (e.g. an on-buy
## "⤵ ➡ 🂠" with an empty hand): the rest of that effect list is skipped.
var cost_unpaid := false


func resolve(target: GameRules.Target) -> PlayerState:
	return owner if target == GameRules.Target.SELF else opponent

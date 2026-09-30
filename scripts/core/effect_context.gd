class_name EffectContext
extends RefCounted
## Everything an effect needs to know when it resolves.

var encounter: Encounter
var owner: PlayerState          ## Whoever owns the card/item/trinket.
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
## An item effect set this when the player declined an optional ability, so
## the item isn't marked as used.
var declined := false
## The pile a card came from (GameRules.PILE_*), for trash triggers.
var from_pile := 0


func resolve(target: GameRules.Target) -> PlayerState:
	return owner if target == GameRules.Target.SELF else opponent

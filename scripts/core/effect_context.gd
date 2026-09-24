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


func resolve(target: GameRules.Target) -> PlayerState:
	return owner if target == GameRules.Target.SELF else opponent

class_name GameRules
extends RefCounted
## Global rule tunables and shared enums for Card Sharks.
## Change numbers here rather than hunting through the code.

enum Target { SELF, OPPONENT }

## Where a card goes when bought / added.
## There is no "shuffle into the deck": the deck is only ever shuffled at the start of the encounter.
enum Zone { HAND, DRAW_TOP, DISCARD, DRAW_BOTTOM }

## Card piles an effect can pick from (bit flags, combine with |).
const PILE_HAND := 1
const PILE_DRAW := 2
const PILE_DISCARD := 4
## "Remove / destroy" pick from the deck, hand or discard unless stated otherwise.
const PILES_ALL := PILE_HAND | PILE_DRAW | PILE_DISCARD

## Moments that passive items can react to.
enum Trigger {
	ENCOUNTER_START,
	ROUND_START,
	TURN_START,            ## Start of your turn (= start of the round, after drawing).
	BEFORE_CARD_BUY,       ## Fires before a card is placed; can change its destination.
	CARD_BOUGHT,
	CARD_PLAYED,
	ITEM_BOUGHT,
	TRINKET_USED,
	OPPONENT_CARD_BOUGHT,
	OPPONENT_CARD_PLAYED,
	ROUND_END,
	ENEMY_ACTED,           ## After the enemy resolves an intent (fires for both sides).
	HAND_DRAWN,            ## Right after the start-of-turn draw (extra draws here don't count as "drawn this turn").
	CARD_DRAWN,            ## Each card drawn (ctx.card; ctx.opening_draw during the start-of-turn draw).
	CURSE_DRAWN,           ## Each curse drawn, including the opening hand.
	CARD_DISCARDED,        ## Each card discarded by an effect (not the end-of-round cleanup).
	CARD_REMOVED,          ## A card was removed for the encounter.
	CARD_DESTROYED,        ## A card was destroyed permanently.
	CARD_TRASHED_FROM_HAND, ## A card in your hand was removed or destroyed.
}

## Terminology: a TURN is your whole round (draw a hand, act until you pass).
## Within it you take ACTIONS one at a time; the enemy may answer an action.
enum TrinketLimit { PER_TURN, PER_ACTION }

const HAND_SIZE := 5
## Bought cards go to the bottom of your deck.
const DEFAULT_BUY_DESTINATION := Zone.DRAW_BOTTOM
const DISCARD_HAND_AT_ROUND_END := true
## Trinkets: usable once per turn (= once per round).
const TRINKET_LIMIT := TrinketLimit.PER_TURN
## You can own at most this many trinkets. Buying the same trinket again
## upgrades it instead; sell one to make room for a new one.
const MAX_TRINKETS := 3

## Which purchases use up your one action for the turn.
const CARD_BUY_IS_ACTION := true
const ITEM_BUY_IS_ACTION := true
const TRINKET_BUY_IS_ACTION := true
const ENHANCEMENT_BUY_IS_ACTION := true
## Selling a trinket (drag it onto the market) is a free action.
const TRINKET_SELL_IS_ACTION := false

## The enemy answers each of your actions with its next intent, until it has
## used EnemyData.actions_per_round for this round.

## Seconds before the enemy's intent resolves, so the player can follow along.
const ENEMY_STEP_DELAY := 0.6

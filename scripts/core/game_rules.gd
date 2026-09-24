class_name GameRules
extends RefCounted
## Global rule tunables and shared enums for Card Sharks.
## Change numbers here rather than hunting through the code.

enum Target { SELF, OPPONENT }

## Where a card goes when bought / added.
enum Zone { HAND, DRAW_TOP, DRAW_SHUFFLE, DISCARD }

## Moments that passive items can react to.
enum Trigger {
	ENCOUNTER_START,
	ROUND_START,
	TURN_START,
	BEFORE_CARD_BUY,       ## Fires before a card is placed; can change its destination.
	CARD_BOUGHT,
	CARD_PLAYED,
	ITEM_BOUGHT,
	TRINKET_USED,
	OPPONENT_CARD_BOUGHT,
	OPPONENT_CARD_PLAYED,
	ROUND_END,
	ENEMY_ACTED,           ## After the enemy resolves an intent (fires for both sides).
}

enum TrinketLimit { PER_TURN, PER_ROUND }

const HAND_SIZE := 5
## Concept: bought cards are shuffled into your deck.
const DEFAULT_BUY_DESTINATION := Zone.DRAW_SHUFFLE
const DISCARD_HAND_AT_ROUND_END := true
const TRINKET_LIMIT := TrinketLimit.PER_TURN

## Which purchases use up your one action for the turn.
const CARD_BUY_IS_ACTION := true
const ITEM_BUY_IS_ACTION := true
const TRINKET_BUY_IS_ACTION := true
const TRINKET_UPGRADE_IS_ACTION := true
const ENHANCEMENT_BUY_IS_ACTION := true

## The enemy resolves its next intent after every N player actions.
const ENEMY_ACTS_EVERY := 1

## Seconds before the enemy's intent resolves, so the player can follow along.
const ENEMY_STEP_DELAY := 0.6

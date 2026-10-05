class_name PlayerState
extends RefCounted
## One side of an encounter (the player or the enemy).

var display_name: String
var is_enemy := false
var coins := 0
var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard: Array[CardInstance] = []
## Cards played this round. They return to discard at round end, so they
## can't be redrawn in the same round (prevents infinite draw loops).
var in_play: Array[CardInstance] = []
## Removed for this encounter only / destroyed permanently (both out of play).
var removed: Array[CardInstance] = []
var destroyed: Array[CardInstance] = []
var items: Array[ItemInstance] = []
var trinkets: Array[TrinketInstance] = []
var intent_index := 0   ## Enemy only.
var cards_bought := 0
## Stats usable by effects (GainCoinsPerStatEffect) and card text ({name}).
## "Turn" = your whole round; the opening hand doesn't count as drawn.
var cards_drawn_this_turn := 0
var cards_played_this_turn := 0
var buys_this_round := 0
## Cards played this turn, in order (including replays), for "last card played".
var played_log: Array[CardInstance] = []
## "You can't draw additional cards this turn."
var draw_locked := false
## Extra cards to draw at the start of the next turn.
var bonus_draw_next_turn := 0
## Pending "the next card you play is played an additional time".
var replay_next := 0
## "The next card you buy is drawn immediately."
var next_buy_to_hand := 0
## Scaling bonuses per card id ("increase gain from all P1s by 2").
var card_bonus := {}


func _init(p_name: String, enemy: bool) -> void:
	display_name = p_name
	is_enemy = enemy


func all_cards() -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	out.append_array(draw_pile)
	out.append_array(hand)
	out.append_array(discard)
	out.append_array(in_play)
	return out

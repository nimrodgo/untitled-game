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
var items: Array[ItemInstance] = []
var trinkets: Array[TrinketInstance] = []
var passed := false
var intent_index := 0   ## Enemy only.
var can_shop_items := true   ## Enemies can never buy items/trinkets.
var cards_bought := 0
## Stats usable by effects (GainCoinsPerStatEffect) and card text ({name}).
## "Turn" = your whole round; the opening hand doesn't count as drawn.
var cards_drawn_this_turn := 0
var cards_played_this_turn := 0
var buys_this_round := 0


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

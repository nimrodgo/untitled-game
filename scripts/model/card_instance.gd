class_name CardInstance
extends RefCounted
## A specific copy of a card in someone's deck, with its (at most one) enhancement.

static var _next_uid: int = 1

var uid: int
var data: CardData
## null = not enhanced. A card never holds more than one.
var enhancement: EnhancementData
## Stays in your hand at the end of this turn.
var retain := false


func _init(card_data: CardData) -> void:
	data = card_data
	uid = _next_uid
	_next_uid += 1


func is_instant() -> bool:
	return data.instant or (enhancement != null and enhancement.make_instant)


func is_curse() -> bool:
	return data.curse or (enhancement != null and enhancement.counts_as_curse)


## Kept in hand at the end of the turn (picked by an effect, or by the enhancement).
func is_retained() -> bool:
	return retain or (enhancement != null and enhancement.retain)


func get_on_discard() -> Array[Effect]:
	var out: Array[Effect] = []
	out.append_array(data.on_discard)
	if enhancement:
		out.append_array(enhancement.on_discard)
	return out


## Unplayable curses can't be played at all (from the hand or otherwise).
func is_playable_kind() -> bool:
	return data.playable


func get_on_play() -> Array[Effect]:
	var out: Array[Effect] = []
	out.append_array(data.on_play)
	if enhancement:
		out.append_array(enhancement.extra_on_play)
	return out


func get_cost() -> int:
	return data.cost


func get_name() -> String:
	return data.display_name


## The card's own text. An enhancement never adds text: it shows as a corner icon.
func play_text(vars: Dictionary = {}) -> String:
	return data.get_play_text(vars)


func buy_text(vars: Dictionary = {}) -> String:
	return data.get_buy_text(vars)

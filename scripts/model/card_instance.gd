class_name CardInstance
extends RefCounted
## A specific copy of a card in someone's deck, with its enhancements.

static var _next_uid: int = 1

var uid: int
var data: CardData
var enhancements: Array[EnhancementData] = []
## Stays in your hand at the end of this turn.
var retain := false


func _init(card_data: CardData) -> void:
	data = card_data
	uid = _next_uid
	_next_uid += 1


func is_instant() -> bool:
	if data.instant:
		return true
	for e in enhancements:
		if e.make_instant:
			return true
	return false


func is_curse() -> bool:
	if data.curse:
		return true
	for e in enhancements:
		if e.counts_as_curse:
			return true
	return false


## Kept in hand at the end of the turn (picked by an effect, or an enhancement).
func is_retained() -> bool:
	if retain:
		return true
	for e in enhancements:
		if e.retain:
			return true
	return false


## Destroyed right after it resolves instead of going to the discard pile.
func destroys_on_play() -> bool:
	for e in enhancements:
		if e.destroy_on_play:
			return true
	return false


func get_on_discard() -> Array[Effect]:
	var out: Array[Effect] = []
	out.append_array(data.on_discard)
	for e in enhancements:
		out.append_array(e.on_discard)
	return out


## Unplayable curses can't be played at all (from the hand or otherwise).
func is_playable_kind() -> bool:
	return data.playable


func get_on_play() -> Array[Effect]:
	var out: Array[Effect] = []
	out.append_array(data.on_play)
	for e in enhancements:
		out.append_array(e.extra_on_play)
	return out


func get_cost() -> int:
	return data.cost


func get_name() -> String:
	return data.display_name + "+".repeat(enhancements.size())


func play_text(vars: Dictionary = {}) -> String:
	var t := data.get_play_text(vars)
	for e in enhancements:
		var et := e.card_text()
		if et != "":
			t += (". " if t != "" else "") + et
	return t


func buy_text(vars: Dictionary = {}) -> String:
	return data.get_buy_text(vars)

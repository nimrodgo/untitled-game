class_name CardInstance
extends RefCounted
## A specific copy of a card in someone's deck, with its enhancements.

static var _next_uid: int = 1

var uid: int
var data: CardData
var enhancements: Array[EnhancementData] = []


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


func play_text() -> String:
	return Effect.describe_list(get_on_play())


func buy_text() -> String:
	return Effect.describe_list(data.on_buy)

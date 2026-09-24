class_name ShopState
extends RefCounted
## The encounter's shop. Slots hold data or null (empty).

var cards: Array = []
var items: Array = []
var trinkets: Array = []
var enhancements: Array = []

var _data: EncounterData
var _rng: RandomNumberGenerator
var _item_bag: Array = []
var _trinket_bag: Array = []
var _enh_bag: Array = []


func setup(data: EncounterData, rng: RandomNumberGenerator) -> void:
	_data = data
	_rng = rng
	_item_bag = _shuffled(data.item_pool)
	_trinket_bag = _shuffled(data.trinket_pool)
	_enh_bag = _shuffled(data.enhancement_pool)
	cards.clear(); items.clear(); trinkets.clear(); enhancements.clear()
	for i in data.card_slots:
		cards.append(_random_card())
	for i in data.item_slots:
		items.append(_item_bag.pop_back() if not _item_bag.is_empty() else null)
	for i in data.trinket_slots:
		trinkets.append(_trinket_bag.pop_back() if not _trinket_bag.is_empty() else null)
	for i in data.enhancement_slots:
		enhancements.append(_enh_bag.pop_back() if not _enh_bag.is_empty() else null)


## New round: fresh cards in every card slot; sold-out item / trinket /
## upgrade slots are refilled from what's left in their pools.
func restock() -> void:
	for i in cards.size():
		cards[i] = _random_card()
	for i in items.size():
		if items[i] == null and not _item_bag.is_empty():
			items[i] = _item_bag.pop_back()
	for i in trinkets.size():
		if trinkets[i] == null and not _trinket_bag.is_empty():
			trinkets[i] = _trinket_bag.pop_back()
	for i in enhancements.size():
		if enhancements[i] == null and not _enh_bag.is_empty():
			enhancements[i] = _enh_bag.pop_back()


func take_card(slot: int) -> CardData:
	var c: CardData = cards[slot]
	cards[slot] = _random_card() if _data.refill_card_slots else null
	return c


func snatch_card(mode: int, rng: RandomNumberGenerator) -> CardData:
	var filled: Array[int] = []
	for i in cards.size():
		if cards[i] != null:
			filled.append(i)
	if filled.is_empty():
		return null
	var pick: int = filled[0]
	match mode:
		SnatchShopCardEffect.Mode.CHEAPEST:
			for i in filled:
				if cards[i].cost < cards[pick].cost: pick = i
		SnatchShopCardEffect.Mode.PRICIEST:
			for i in filled:
				if cards[i].cost > cards[pick].cost: pick = i
		SnatchShopCardEffect.Mode.RANDOM:
			pick = filled[rng.randi_range(0, filled.size() - 1)]
	return take_card(pick)


func take_item(slot: int) -> ItemData:
	var it: ItemData = items[slot]
	items[slot] = null
	return it


func take_trinket(slot: int) -> TrinketData:
	var t: TrinketData = trinkets[slot]
	trinkets[slot] = null
	return t


func take_enhancement(slot: int) -> EnhancementData:
	var e: EnhancementData = enhancements[slot]
	enhancements[slot] = null
	return e


func _random_card() -> CardData:
	if _data.card_pool.is_empty():
		return null
	return _data.card_pool[_rng.randi_range(0, _data.card_pool.size() - 1)]


func _shuffled(src: Array) -> Array:
	var a := src.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = a[i]; a[i] = a[j]; a[j] = tmp
	return a

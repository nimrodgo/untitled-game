class_name EncounterData
extends Resource
## One encounter = one shop + one opponent.

@export var display_name: String = "Encounter"
@export var rounds: int = 3
## Have at least this many coins after the last round to win.
@export var coin_target: int = 15
@export var gold_reward: int = 10
@export var enemy: EnemyData

@export_group("Shop")
## Just name the sets: every card, charm, trinket and enhancement of these sets, plus Utility
## and Coins (CardSets.ALWAYS_SOLD), is sold here (see ContentLibrary). Leave
## empty to use only the pools below.
@export var card_sets: Array[CardSets.Id] = []
## Extra pieces on top of the sets (or the whole pool if `card_sets` is empty);
## duplicates make a card more likely. The market restocks from the pool at the
## start of every round (bought slots stay empty until then).
@export var card_pool: Array[CardData] = []
@export var charm_pool: Array[CharmData] = []
@export var trinket_pool: Array[TrinketData] = []
@export var enhancement_pool: Array[EnhancementData] = []
@export var card_slots: int = 5
@export var charm_slots: int = 1
@export var trinket_slots: int = 1
@export var enhancement_slots: int = 1
## Legacy: refill a card slot immediately when it's bought (off = restock per round).
@export var refill_card_slots: bool = false

@export_group("Debug")
## 0 = random each time.
@export var rng_seed: int = 0


## What the shop actually draws from: the pieces of `card_sets` (+ Utility and
## Coins), then the manual pools.
func get_card_pool() -> Array[CardData]:
	var out: Array[CardData] = []
	for c in _from_sets(ContentLibrary.cards()):
		out.append(c)
	out.append_array(card_pool)
	return out


func get_charm_pool() -> Array[CharmData]:
	var out: Array[CharmData] = []
	for c in _from_sets(ContentLibrary.charms()):
		out.append(c)
	out.append_array(charm_pool)
	return out


func get_trinket_pool() -> Array[TrinketData]:
	var out: Array[TrinketData] = []
	for c in _from_sets(ContentLibrary.trinkets()):
		out.append(c)
	out.append_array(trinket_pool)
	return out


func get_enhancement_pool() -> Array[EnhancementData]:
	var out: Array[EnhancementData] = []
	for c in _from_sets(ContentLibrary.enhancements()):
		out.append(c)
	out.append_array(enhancement_pool)
	return out


func _from_sets(all: Array) -> Array:
	if card_sets.is_empty():
		return []
	var wanted: Array = card_sets.duplicate()
	wanted.append_array(CardSets.ALWAYS_SOLD)
	return ContentLibrary.in_sets(all, wanted)

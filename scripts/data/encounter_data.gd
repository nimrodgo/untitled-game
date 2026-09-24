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
## Card pool; duplicates make a card more likely. Card slots refill from it.
@export var card_pool: Array[CardData] = []
@export var item_pool: Array[ItemData] = []
@export var trinket_pool: Array[TrinketData] = []
@export var enhancement_pool: Array[EnhancementData] = []
@export var card_slots: int = 5
@export var item_slots: int = 2
@export var trinket_slots: int = 1
@export var enhancement_slots: int = 1
@export var refill_card_slots: bool = true

@export_group("Debug")
## 0 = random each time.
@export var rng_seed: int = 0

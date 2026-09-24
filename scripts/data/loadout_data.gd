class_name LoadoutData
extends Resource
## What the player brings into an encounter (later this will come from the run).

@export var starting_deck: Array[CardData] = []
@export var starting_coins: int = 3
@export var items: Array[ItemData] = []
@export var trinkets: Array[TrinketData] = []

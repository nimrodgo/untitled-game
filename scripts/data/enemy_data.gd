class_name EnemyData
extends Resource
## An enemy is a rule-follower, not a card player: it steps through `intents`
## in order (looping). The next intent is always shown to the player.

@export var display_name: String = "Enemy"
@export var starting_coins: int = 0
@export var intents: Array[EnemyIntent] = []
## How many intents it resolves per round. It answers your actions one by one
## until these run out; after that you act freely until you pass.
@export var actions_per_round: int = 3
## Index of the first intent (lets two copies of an enemy be out of phase).
@export var start_intent: int = 0
## Passive items the enemy starts with (it can never buy more).
@export var items: Array[ItemData] = []
@export var portrait: Texture2D
@export var color: Color = Color("ff7f6a")

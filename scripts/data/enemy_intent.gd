class_name EnemyIntent
extends Resource
## One step of an enemy's scripted pattern (like Slay the Spire intents).
## Effects resolve with the ENEMY as owner, so target OPPONENT = the player.

enum Kind { ATTACK, STEAL, SHOP, CURSE, BUFF, OTHER }

@export var display_name: String = "Intent"
@export var kind: Kind = Kind.ATTACK
@export var effects: Array[Effect] = []
## Leave empty to auto-generate from the effects.
@export_multiline var description: String = ""
@export var icon: Texture2D


func get_description() -> String:
	return description if description != "" else Effect.describe_list(effects, true)


## Short label for the intent type (plain text: web builds have no emoji font).
static func kind_label(k: Kind) -> String:
	match k:
		Kind.ATTACK: return "ATTACK"
		Kind.STEAL: return "STEAL"
		Kind.SHOP: return "SHOP"
		Kind.CURSE: return "CURSE"
		Kind.BUFF: return "BUFF"
	return "OTHER"

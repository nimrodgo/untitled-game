class_name TrinketLevel
extends Resource
## One level of a trinket. Level 1's upgrade_cost is ignored.

@export var upgrade_cost: int = 3
@export var effects: Array[Effect] = []
## Text shown for this level. Leave empty to auto-generate from the effects.
@export_multiline var text: String = ""


func get_text() -> String:
	return text if text != "" else Effect.describe_list(effects)

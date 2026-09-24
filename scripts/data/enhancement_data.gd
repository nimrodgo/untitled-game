class_name EnhancementData
extends Resource
## A shop upgrade applied to one card in your hand (permanently, for the run).

@export var id: StringName
@export var display_name: String = "New Enhancement"
@export var cost: int = 2
@export var make_instant: bool = false
@export var extra_on_play: Array[Effect] = []
@export_multiline var description: String = ""


func get_description() -> String:
	if description != "":
		return description
	var parts: PackedStringArray = []
	if make_instant:
		parts.append("Card becomes Instant")
	if not extra_on_play.is_empty():
		parts.append("On play: " + Effect.describe_list(extra_on_play))
	return ". ".join(parts)

class_name EffectOption
extends Resource
## One branch of a ChooseOneEffect.

@export var label: String = ""
@export var effects: Array[Effect] = []


func get_label() -> String:
	return label if label != "" else Effect.describe_list(effects)


func can_pay(ctx: EffectContext) -> bool:
	for e in effects:
		if e and not e.can_pay(ctx):
			return false
	return true

class_name TrinketInstance
extends RefCounted

var data: TrinketData
var level: int = 0   ## index into data.levels
var used := false


func _init(trinket_data: TrinketData) -> void:
	data = trinket_data


func current_effects() -> Array[Effect]:
	if data.levels.is_empty():
		return []
	return data.levels[level].effects


func can_upgrade() -> bool:
	return level + 1 < data.levels.size()


func upgrade_cost() -> int:
	return data.levels[level + 1].upgrade_cost if can_upgrade() else -1


func get_name() -> String:
	return "%s (Lv %d)" % [data.display_name, level + 1]


func get_description() -> String:
	var txt := Effect.describe_list(current_effects())
	if data.description != "":
		txt = data.description + "\n" + txt
	if can_upgrade():
		txt += "\nNext level (%d coins): %s" % [upgrade_cost(), Effect.describe_list(data.levels[level + 1].effects)]
	return txt

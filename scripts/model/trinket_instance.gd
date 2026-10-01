class_name TrinketInstance
extends RefCounted

var data: TrinketData
var level: int = 0   ## index into data.levels
var used := false
## Coins spent on this trinket (purchase + upgrades). Selling returns half, rounded down.
var paid := 0


func _init(trinket_data: TrinketData) -> void:
	data = trinket_data
	paid = trinket_data.cost


func sell_value() -> int:
	return floori(paid / 2.0)


func current_effects() -> Array[Effect]:
	if data.levels.is_empty():
		return []
	return data.levels[level].effects


func can_upgrade() -> bool:
	return level + 1 < data.levels.size()


func upgrade_cost() -> int:
	return data.levels[level + 1].upgrade_cost if can_upgrade() else -1


func get_name() -> String:
	if data.levels.size() <= 1:
		return data.display_name
	return "%s (Lv %d)" % [data.display_name, level + 1]


func get_text() -> String:
	return data.levels[level].get_text() if not data.levels.is_empty() else ""


func get_description() -> String:
	var txt := get_text()
	if data.description != "":
		txt = data.description + "\n" + txt
	if can_upgrade():
		txt += "\nNext level (%d 🪙, buy it again in the shop): %s" % [upgrade_cost(), data.levels[level + 1].get_text()]
	return txt

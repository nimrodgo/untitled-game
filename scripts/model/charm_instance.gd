class_name CharmInstance
extends RefCounted

var data: CharmData
var uses_this_round := 0
var uses_this_encounter := 0


func _init(charm_data: CharmData) -> void:
	data = charm_data


func can_trigger() -> bool:
	if data.limit_per_encounter > 0 and uses_this_encounter >= data.limit_per_encounter:
		return false
	if data.limit_per_round > 0 and uses_this_round >= data.limit_per_round:
		return false
	return true


func mark_used() -> void:
	uses_this_round += 1
	uses_this_encounter += 1

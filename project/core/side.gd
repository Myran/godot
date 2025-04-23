class_name Side extends RefCounted

var lineup: Dictionary[int, UnitData] = {}
var dead_units: Dictionary[int, UnitData] = {}
var activated_units: Array[UnitData] = []


func is_empty() -> bool:
	return lineup.is_empty()


func clear_activated() -> void:
	activated_units.clear()


func has_unit(unit: UnitData) -> bool:
	return unit in activated_units


func add_unit(position: int, unit: UnitData) -> void:
	lineup[position] = unit


func remove_unit(position: int) -> void:
	if lineup.has(position):
		dead_units[position] = lineup[position]
		lineup.erase(position)

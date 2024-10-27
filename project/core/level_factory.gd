class_name LevelFactory extends Resource
@export var tilemap_levels: Dictionary


func create_level(level_name = "default"):
	var ret_level = null
	if tilemap_levels.has(level_name):
		ret_level = tilemap_levels[level_name].instantiate()
	return ret_level

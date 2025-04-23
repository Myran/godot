class_name LevelFactory extends Resource
@export var tilemap_levels: Dictionary[String, PackedScene]


func create_level(level_name: String = "default") -> TileMapLayer:
	var ret_level: TileMapLayer
	if tilemap_levels.has(level_name):
		ret_level = tilemap_levels[level_name].instantiate()
	return ret_level
class_name LevelCollection
extends BaseCollection

var _cache: Array[Dictionary] = []
var _is_cache_initialized: bool = false
var _collection_key: String = ""

## Initialize the level collection with the backend
## @param backend The data backend to use
## @param test_group The test group suffix to use
func _init(backend: DataBackend, test_group: int = 0) -> void:
	super(backend, ["sheets"], "Levels")
	_collection_key = "levels_" + str(test_group)
	Log.info("LevelCollection initialized", {"test_group": test_group}, [Log.TAG_DB])

## Get all levels
## @param use_cache Whether to use the cache if available
## @return Array of level dictionaries
func get_all(use_cache: bool = true) -> Array[Dictionary]:
	if use_cache and _is_cache_initialized:
		return _cache
		
	Log.info("Getting all levels", {}, [Log.TAG_DB])
	var result: Variant = await _backend.get_data(_get_path(), _collection_key)
	
	# Handle case where result is null
	if result == null:
		Log.warning("No level data returned, using empty array", {}, [Log.TAG_DB, Log.TAG_ERROR])
		_cache = []
	else:
		_cache = result
		
	_is_cache_initialized = true
	return _cache
	
## Get a specific level by number
## @param level_nr The level number to retrieve
## @return Level dictionary or empty dictionary if not found
func get_by_number(level_nr: int) -> Dictionary:
	Log.info("Getting level data", {"level": level_nr}, [Log.TAG_DB])
	
	var levels: Array[Dictionary] = await get_all()
	for level: Dictionary in levels:
		var id: Variant = level.id
		if int(id) == level_nr:
			Log.debug("Level data found", {"level": level_nr}, [Log.TAG_DB])
			return level
			
	Log.warning("No level data found for level", {"level": level_nr}, [Log.TAG_DB])
	return {}
	
## Clear the level cache
## @return void
func clear_cache() -> void:
	_is_cache_initialized = false
	_cache = []

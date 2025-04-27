class_name LevelCollection
extends BaseCollection

## Collection class for level data.
## Provides access to level information with caching and validation.

# Cache of retrieved levels
var _cache: Array[Dictionary] = []

# Whether the cache has been initialized
var _is_cache_initialized: bool = false

# Key for retrieving level data
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
		Log.debug("Using level cache", {
			"cache_size": _cache.size(),
			"collection_name": _collection_name,
			"collection_key": _collection_key,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_CACHE])
		return _cache
		
	Log.info("Getting all levels", {
		"use_cache": use_cache,
		"cache_initialized": _is_cache_initialized,
		"collection_name": _collection_name,
		"collection_key": _collection_key,
		"base_path": _base_path,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])
	
	var request_start_time: int = Time.get_ticks_msec()
	var result: Variant = await _backend.get_data(_get_path(), _collection_key)
	var request_duration: int = Time.get_ticks_msec() - request_start_time
	
	Log.debug("Backend get_data call completed", {
		"duration_ms": request_duration,
		"collection_name": _collection_name,
		"collection_key": _collection_key,
		"result_null": result == null,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])
	
	# Handle case where result is null
	if result == null:
		Log.error("No level data returned", {
			"collection_name": _collection_name,
			"collection_key": _collection_key,
			"base_path": _base_path,
			"backend_class": _backend.get_class(),
			"collection_id": get_instance_id(),
			"stack_trace": _get_stack_trace(3)
		}, [Log.TAG_DB, Log.TAG_ERROR])
		
		push_error("Required level data is missing for collection: " + _collection_name + " with key: " + _collection_key)
		
		# For editor testing, create minimal test levels
		var test_levels: Array[Dictionary] = []
		for i: int in range(3):
			var level_number: int = i + 1
			test_levels.append({
				"id": str(level_number),
				"number": level_number,
				"name": "Test Level " + str(level_number),
				"description": "Test level description",
				"difficulty": 1,
				"rewards": {
					"experience": 100 * level_number,
					"gold": 50 * level_number
				},
				"requirements": {
					"player_level": level_number
				}
			})
			
		Log.warning("Using emergency test levels for editor testing ONLY", {
			"count": test_levels.size(),
			"collection_name": _collection_name,
			"collection_id": get_instance_id(),
			"emergency_data": true
		}, [Log.TAG_DB])
		
		_cache = test_levels
	else:
		Log.debug("Processing level data result", {
			"result_type": typeof(result),
			"is_array": result is Array,
			"result_size": result.size() if result is Array else 0,
			"collection_name": _collection_name,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB])
		
		# Use JSONPathNavigator for safe handling if result is not already an array
		if not (result is Array):
			Log.warning("Level data is not an array, attempting to navigate result", {
				"collection_name": _collection_name,
				"result_type": typeof(result),
				"collection_id": get_instance_id()
			}, [Log.TAG_DB, Log.TAG_WARNING])
			
			var nav_result: NavigationResultClass = JSONPathNavigator.navigate(result, [])
			if nav_result.is_array():
				result = nav_result.as_array()
			elif nav_result.is_dictionary():
				# Try to extract levels from dictionary structure
				var levels_result: NavigationResult = JSONPathNavigator.navigate(nav_result.value, ["levels"])
				if levels_result.is_array():
					result = levels_result.as_array()
				else:
					# Use first array found in dictionary as fallback
					for key in nav_result.as_dictionary().keys():
						var value: Variant = nav_result.as_dictionary()[key]
						if value is Array:
							Log.warning("Using array found at key: " + str(key), {
								"collection_name": _collection_name,
								"collection_id": get_instance_id()
							}, [Log.TAG_DB, Log.TAG_WARNING])
							result = value
							break
		
		if result is Array:
			_cache = result
		else:
			Log.error("Failed to process level data", {
				"collection_name": _collection_name,
				"result_type": typeof(result),
				"collection_id": get_instance_id()
			}, [Log.TAG_DB, Log.TAG_ERROR])
			_cache = []
		
	_is_cache_initialized = true
	
	# Log detailed results
	Log.info("Retrieved all levels", {
		"count": _cache.size(),
		"collection_name": _collection_name,
		"collection_key": _collection_key,
		"empty_result": _cache.size() == 0,
		"duration_ms": request_duration,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])
	
	# Validate important fields in the levels
	if _cache.size() > 0:
		var sample_level: Dictionary = _cache[0]
		var sample_level_keys: Array[String] = sample_level.keys()
		var required_keys: Array[String] = ["id", "number", "name"]
		var missing_keys: Array[String] = []
		
		Log.debug("Validating level data structure", {
			"sample_level_keys": sample_level_keys,
			"required_keys": required_keys,
			"collection_name": _collection_name,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB])
		
		for key: String in required_keys:
			if not sample_level.has(key):
				missing_keys.append(key)
				
		if missing_keys.size() > 0:
			Log.error("Level data missing required fields", {
				"missing_keys": missing_keys,
				"available_keys": sample_level_keys,
				"collection_name": _collection_name,
				"collection_id": get_instance_id(),
				"stack_trace": _get_stack_trace(3)
			}, [Log.TAG_DB, Log.TAG_ERROR])
			
			push_error("Level data missing required fields: " + str(missing_keys) + 
				". Available keys: " + str(sample_level_keys))
		else:
			Log.debug("Level data validation successful", {
				"collection_name": _collection_name,
				"collection_id": get_instance_id()
			}, [Log.TAG_DB])
	else:
		Log.warning("No levels found to validate structure", {
			"collection_name": _collection_name,
			"collection_key": _collection_key,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_WARNING])
	
	return _cache

## Get a specific level by ID
## @param level_id The ID of the level to retrieve
## @param use_cache Whether to use the cache if available
## @return Level dictionary or empty dictionary if not found
func get_by_id(level_id: String, use_cache: bool = true) -> Dictionary:
	Log.info("Getting level info", {"level_id": level_id, "use_cache": use_cache}, [Log.TAG_DB])
	
	var levels: Array[Dictionary] = await get_all(use_cache)
	for level: Dictionary in levels:
		if not level is Dictionary:
			continue
			
		var level_dict: Dictionary = level
		if not level_dict.has("id"):
			continue
			
		var id: String = str(level_dict.id)
		if id == level_id:
			Log.debug("Level found", {"level_id": level_id}, [Log.TAG_DB])
			return level_dict
			
	Log.error("Level with id not found", {"level_id": level_id}, [Log.TAG_DB, Log.TAG_ERROR])
	return {}

## Get a specific level by number
## @param level_nr The number of the level to retrieve
## @param use_cache Whether to use the cache if available
## @return Level dictionary or empty dictionary if not found
func get_by_number(level_nr: int, use_cache: bool = true) -> Dictionary:
	Log.info("Getting level data", {"level": level_nr}, [Log.TAG_DB])
	
	var levels: Array[Dictionary] = await get_all(use_cache)
	for level: Dictionary in levels:
		if not level is Dictionary:
			continue
			
		var level_dict: Dictionary = level
		if not level_dict.has("id"):
			continue
		
		# Handle both string and int representations of id
		var id: int
		if level_dict.id is int:
			id = level_dict.id
		elif level_dict.id is String and level_dict.id.is_valid_int():
			id = level_dict.id.to_int()
		else:
			continue
			
		if id == level_nr:
			Log.debug("Level data found", {"level": level_nr}, [Log.TAG_DB])
			return level_dict
			
	Log.warning("No level data found for level", {"level": level_nr}, [Log.TAG_DB])
	return {}

## Get levels up to a specific number
## @param max_level The maximum level number to include
## @param use_cache Whether to use the cache if available
## @return Array of level dictionaries up to and including max_level
func get_levels_up_to(max_level: int, use_cache: bool = true) -> Array[Dictionary]:
	Log.info("Getting levels up to", {"max_level": max_level, "use_cache": use_cache}, [Log.TAG_DB])
	
	var levels: Array[Dictionary] = await get_all(use_cache)
	var filtered_levels: Array[Dictionary] = []
	
	for level: Dictionary in levels:
		if not level is Dictionary:
			continue
			
		var level_dict: Dictionary = level
		if not level_dict.has("id"):
			continue
		
		# Handle both string and int representations of id
		var id: int
		if level_dict.id is int:
			id = level_dict.id
		elif level_dict.id is String and level_dict.id.is_valid_int():
			id = level_dict.id.to_int()
		else:
			continue
			
		if id <= max_level:
			filtered_levels.append(level_dict)
	
	# Sort levels by id
	filtered_levels.sort_custom(func(a, b):
		var a_id: int = a.id if a.id is int else int(a.id)
		var b_id: int = b.id if b.id is int else int(b.id)
		return a_id < b_id
	)
			
	Log.debug("Found levels up to max", {
		"max_level": max_level, 
		"count": filtered_levels.size()
	}, [Log.TAG_DB])
	
	return filtered_levels

## Clear the level cache
## @return void
func clear_cache() -> void:
	Log.info("Clearing level cache", {}, [Log.TAG_DB, Log.TAG_CACHE])
	_is_cache_initialized = false
	_cache = []

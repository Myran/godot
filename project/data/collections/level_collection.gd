class_name LevelCollection
extends BaseCollection

var _is_cache_initialized: bool = false
var _collection_key: String = ""
var _level_cache: Array[Dictionary] = []


func _init(backend: DataBackend, test_group: int = 0) -> void:
	var base_path: Array[Variant] = []
	base_path.append(data_source.DEFAULT_SHEETS_ID)
	super(backend, base_path, "Levels")
	_collection_key = "levels_" + str(test_group)
	Log.info("LevelCollection initialized", {"test_group": test_group}, [Log.TAG_DB])


func get_all(use_cache: bool = true) -> Array[Dictionary]:
	if use_cache and _is_cache_initialized:
		return _level_cache

	Log.info("Getting all levels", {}, [Log.TAG_DB])
	@warning_ignore("redundant_await")
	var result: Variant = await _backend.get_data(_get_path(), _collection_key)

	if result == null:
		Log.warning("No level data returned, using empty array", {}, [Log.TAG_DB, Log.TAG_ERROR])
		_level_cache = []
	elif result is Array:
		if result is Array:
			var array_result: Array = result
			_level_cache = []
			for item: Variant in array_result:
				if item is Dictionary:
					_level_cache.append(item)
		else:
			Log.error(
				"Invalid data type for level data",
				{"actual_type": typeof(result)},
				[Log.TAG_DB, Log.TAG_ERROR]
			)
			_level_cache = []
	else:
		Log.error(
			"Expected Array but got different type",
			{"type": typeof(result)},
			[Log.TAG_DB, Log.TAG_ERROR]
		)
		_level_cache = []

	_is_cache_initialized = true
	return _level_cache


func get_by_number(level_nr: int) -> Dictionary:
	Log.info("Getting level data", {"level": level_nr}, [Log.TAG_DB])

	@warning_ignore("redundant_await")
	@warning_ignore("redundant_await")
	var levels: Array[Dictionary] = await get_all()
	for level: Dictionary in levels:
		var id: Variant = level.id
		if id is int and id == level_nr:
			Log.debug("Level data found", {"level": level_nr}, [Log.TAG_DB])
			return level
		elif id is String and id.is_valid_int() and id.to_int() == level_nr:
			Log.debug("Level data found", {"level": level_nr}, [Log.TAG_DB])
			return level

	Log.warning("No level data found for level", {"level": level_nr}, [Log.TAG_DB])
	return {}


func clear_cache() -> void:
	_is_cache_initialized = false
	_level_cache = []
	super.clear_cache()

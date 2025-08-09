class_name BaseCollection
extends RefCounted

var _backend: DataBackend
var _base_path: Array[Variant] = []
var _collection_name: String = ""
var _cache: Dictionary = {}
var _cache_enabled: bool = true


func _init(backend: DataBackend, base_path: Array = [], collection_name: String = "") -> void:
	assert(backend is DataBackend, "Backend must be a DataBackend instance")

	_backend = backend

	if base_path is Array:
		for item: Variant in base_path:
			_base_path.append(item)

	_collection_name = collection_name
	Log.debug(
		"BaseCollection initialized",
		{"collection_name": _collection_name, "base_path": _base_path},
		[Log.TAG_DB]
	)


func _get_path() -> Array[Variant]:
	return _base_path.duplicate()


func get_data(path: Array[Variant], key: String, use_cache: bool = true) -> Variant:
	var cache_key: String = _get_cache_key(path) + "/" + key

	if _cache_enabled and use_cache and _cache.has(cache_key):
		Log.debug(
			"Cache hit",
			{"collection": _collection_name, "cache_key": cache_key},
			[Log.TAG_DB, Log.TAG_CACHE]
		)
		return _cache[cache_key]

	var data: Variant = await _backend.get_data(path, key)

	if _cache_enabled and data != null:
		_cache[cache_key] = data
		Log.debug(
			"Cache updated",
			{"collection": _collection_name, "cache_key": cache_key},
			[Log.TAG_DB, Log.TAG_CACHE]
		)

	return data


func get_data_as_dictionary(
	path: Array[Variant], key: String, use_cache: bool = true
) -> Dictionary:
	var data: Variant = await get_data(path, key, use_cache)

	if data is Dictionary:
		return data

	Log.warning(
		"Data is not a dictionary",
		{"collection": _collection_name, "path": path, "actual_type": typeof(data)},
		[Log.TAG_DB, Log.TAG_WARNING]
	)

	return {}


func get_data_as_array(path: Array[Variant], key: String, use_cache: bool = true) -> Array:
	var data: Variant = await get_data(path, key, use_cache)

	if data is Array:
		return data

	Log.warning(
		"Data is not an array",
		{"collection": _collection_name, "path": path, "actual_type": typeof(data)},
		[Log.TAG_DB, Log.TAG_WARNING]
	)

	return []


func get_data_as_string(
	path: Array[Variant], key: String, use_cache: bool = true, default_value: String = ""
) -> String:
	var data: Variant = await get_data(path, key, use_cache)

	if data is String:
		return data

	if data != null:
		Log.debug(
			"Converting non-string data to string",
			{"collection": _collection_name, "path": path, "actual_type": typeof(data)},
			[Log.TAG_DB]
		)
		return str(data)

	return default_value


func get_data_as_int(
	path: Array[Variant], key: String, use_cache: bool = true, default_value: int = 0
) -> int:
	var data: Variant = await get_data(path, key, use_cache)

	if data is int:
		return data

	if data is float:
		Log.debug(
			"Converting float to int",
			{"collection": _collection_name, "path": path, "value": data},
			[Log.TAG_DB]
		)
		var float_value: float = data
		return int(float_value)

	if data is String:
		var string_value: String = data
		if string_value.is_valid_int():
			Log.debug(
				"Converting string to int",
				{"collection": _collection_name, "path": path, "value": data},
				[Log.TAG_DB]
			)
			return string_value.to_int()

	return default_value


func save_data(path: Array[Variant], data: Variant) -> bool:
	var success: bool = await _backend.save_data(path, data)

	if success and _cache_enabled:
		var cache_key: String = _get_cache_key(path)
		_cache[cache_key] = data
		Log.debug(
			"Cache updated after save",
			{"collection": _collection_name, "cache_key": cache_key},
			[Log.TAG_DB, Log.TAG_CACHE]
		)

	return success


func _get_cache_key(path: Array[Variant]) -> String:
	var key: String = ""
	for part: Variant in path:
		key += str(part) + "/"
	return key.strip_edges(false, true)


func clear_cache() -> void:
	_cache.clear()
	Log.debug("Cache cleared", {"collection": _collection_name}, [Log.TAG_DB, Log.TAG_CACHE])


func enable_cache() -> void:
	_cache_enabled = true
	Log.debug("Cache enabled", {"collection": _collection_name}, [Log.TAG_DB, Log.TAG_CACHE])


func disable_cache() -> void:
	_cache_enabled = false
	Log.debug("Cache disabled", {"collection": _collection_name}, [Log.TAG_DB, Log.TAG_CACHE])


func is_cache_enabled() -> bool:
	return _cache_enabled


func get_cache_size() -> int:
	return _cache.size()


func is_cached(path: Array[Variant]) -> bool:
	var cache_key: String = _get_cache_key(path)
	return _cache.has(cache_key)


func create_navigator(data: Variant) -> Object:
	return JSONPathNavigator.navigate(data, [])


func path_string_to_array(string_path: String, separator: String = "/") -> Array[Variant]:
	var parts: PackedStringArray = string_path.split(separator)
	var result: Array[Variant] = []

	for part: String in parts:
		if part.is_empty():
			continue

		if part.is_valid_int():
			result.append(part.to_int())
		else:
			result.append(part)

	return result

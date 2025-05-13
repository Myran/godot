class_name BaseCollection
extends RefCounted

## Base class for all data collections.
## Provides common functionality for data access and caching.

var _backend: DataBackend
var _base_path: Array[Variant] = []
var _collection_name: String = ""
var _cache: Dictionary = {}
var _cache_enabled: bool = true


## Initialize the collection with backend and path information
## @param backend The data backend to use
## @param base_path Base path for the collection in the database
## @param collection_name Human-readable name for the collection
func _init(backend: DataBackend, base_path: Array = [], collection_name: String = "") -> void:
	# Validate the backend parameter
	assert(backend is DataBackend, "Backend must be a DataBackend instance")

	_backend = backend

	# Convert base_path to Array[Variant] if needed
	if base_path is Array:
		for item: Variant in base_path:
			_base_path.append(item)

	_collection_name = collection_name
	Log.debug(
		"BaseCollection initialized",
		{"collection_name": _collection_name, "base_path": _base_path},
		[Log.TAG_DB]
	)


## Get the full path for this collection
## @return The complete path to this collection
func _get_path() -> Array[Variant]:
	return _base_path.duplicate()


## Get data from the backend with caching
## @param path The path to get data from
## @param key The key to retrieve
## @param use_cache Whether to use the cache
## @return The data from the backend
func get_data(path: Array[Variant], key: String, use_cache: bool = true) -> Variant:
	# Calculate cache key
	var cache_key: String = _get_cache_key(path) + "/" + key

	# Check cache if enabled and requested
	if _cache_enabled and use_cache and _cache.has(cache_key):
		Log.debug(
			"Cache hit",
			{"collection": _collection_name, "cache_key": cache_key},
			[Log.TAG_DB, Log.TAG_CACHE]
		)
		return _cache[cache_key]

	# Get data from backend
	var data: Variant = await _backend.get_data(path, key)

	# Cache data if caching is enabled
	if _cache_enabled and data != null:
		_cache[cache_key] = data
		Log.debug(
			"Cache updated",
			{"collection": _collection_name, "cache_key": cache_key},
			[Log.TAG_DB, Log.TAG_CACHE]
		)

	return data


## Get data as dictionary with type safety
## @param path The path to get data from
## @param key The key to retrieve
## @param use_cache Whether to use the cache
## @return The data as a dictionary
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


## Get data as array with type safety
## @param path The path to get data from
## @param key The key to retrieve
## @param use_cache Whether to use the cache
## @return The data as an array
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


## Get data as string with type safety
## @param path The path to get data from
## @param key The key to retrieve
## @param use_cache Whether to use the cache
## @param default_value Default value if data is not a string
## @return The data as a string
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


## Get data as integer with type safety
## @param path The path to get data from
## @param key The key to retrieve
## @param use_cache Whether to use the cache
## @param default_value Default value if data is not an integer
## @return The data as an integer
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


## Save data to the backend
## @param path The path to save data to
## @param data The data to save
## @return True if save was successful, false otherwise
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


## Generate a cache key from a path
## @param path The path to generate a cache key for
## @return The cache key
func _get_cache_key(path: Array[Variant]) -> String:
	var key: String = ""
	for part in path:
		key += str(part) + "/"
	return key.strip_edges(false, true)


## Clear the cache for this collection
func clear_cache() -> void:
	_cache.clear()
	Log.debug("Cache cleared", {"collection": _collection_name}, [Log.TAG_DB, Log.TAG_CACHE])


## Enable caching for this collection
func enable_cache() -> void:
	_cache_enabled = true
	Log.debug("Cache enabled", {"collection": _collection_name}, [Log.TAG_DB, Log.TAG_CACHE])


## Disable caching for this collection
func disable_cache() -> void:
	_cache_enabled = false
	Log.debug("Cache disabled", {"collection": _collection_name}, [Log.TAG_DB, Log.TAG_CACHE])


## Check if caching is enabled for this collection
## @return True if caching is enabled, false otherwise
func is_cache_enabled() -> bool:
	return _cache_enabled


## Get the size of the cache
## @return The number of items in the cache
func get_cache_size() -> int:
	return _cache.size()


## Check if a path exists in the cache
## @param path The path to check
## @return True if the path exists in the cache, false otherwise
func is_cached(path: Array[Variant]) -> bool:
	var cache_key: String = _get_cache_key(path)
	return _cache.has(cache_key)


## Create a JSONPathNavigator for safer access to data
## @param data The data to navigate
## @return A JSONPathNavigator instance
func create_navigator(data: Variant) -> Object:
	# Note: We don't use the specific return type to avoid casting issues
	return JSONPathNavigator.navigate(data, [])


## Convert a string path to an array path
## @param string_path The string path to convert
## @param separator The separator to use
## @return The array path
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

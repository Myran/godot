class_name BaseCollection
extends RefCounted

## Base class for all data collections.
## Provides common functionality and interface for accessing data through backends.
## Includes cache management with TTL support.

# Backend responsible for data retrieval
var _backend: DataBackend

# Base path in the data structure
var _base_path: Array = []

# Human-readable name for the collection
var _collection_name: String = ""

# Cache manager for this collection
var _cache_manager: CacheManager

## Initialize the collection with backend and path information
## @param backend The data backend to use
## @param base_path Base path for the collection in the database
## @param collection_name Human-readable name for the collection
## @param ttl Default TTL for cache entries in seconds (0 = use project setting)
func _init(backend: DataBackend, base_path: Array = [], collection_name: String = "", ttl: int = 0) -> void:
	_backend = backend
	_base_path = base_path
	_collection_name = collection_name
	
	# Initialize cache manager
	_cache_manager = CacheManager.new(ttl)
	
	Log.debug("BaseCollection initialized", {
		"collection_name": _collection_name,
		"base_path": _base_path,
		"collection_id": get_instance_id(),
		"default_ttl": _cache_manager.default_ttl
	}, [Log.TAG_DB])

## Get the full path for this collection
## @return The complete path to this collection
func _get_path() -> Array:
	return _base_path.duplicate()

## Get data from the backend with proper error handling
## @param key The key to retrieve data for
## @param custom_path Optional custom path to use instead of the collection's base path
## @return Variant The retrieved data or null if not found
func _get_data(key: String, custom_path: Array = []) -> Variant:
	var path: Array = custom_path if custom_path.size() > 0 else _get_path()
	
	Log.debug("Getting data", {
		"collection": _collection_name,
		"key": key,
		"path": path,
		"collection_id": get_instance_id(),
		"stack_trace": _get_stack_trace(2)
	}, [Log.TAG_DB])
	
	var result: Variant = await _backend.get_data(path, key)
	
	if result == null:
		Log.error("Data not found", {
			"collection": _collection_name,
			"key": key,
			"path": path,
			"collection_id": get_instance_id(),
			"stack_trace": _get_stack_trace(3)
		}, [Log.TAG_DB, Log.TAG_ERROR])
	else:
		Log.debug("Data retrieved successfully", {
			"collection": _collection_name,
			"key": key,
			"is_array": result is Array,
			"is_dictionary": result is Dictionary,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB])
	
	return result

## Set data in the backend with proper error handling
## @param key The key to set data for
## @param data The data to set
## @param custom_path Optional custom path to use instead of the collection's base path
## @return bool True if data was set successfully
func _set_data(key: String, data: Variant, custom_path: Array = []) -> bool:
	var path: Array = custom_path if custom_path.size() > 0 else _get_path()
	
	Log.debug("Setting data", {
		"collection": _collection_name,
		"key": key,
		"path": path,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])
	
	var success: bool = await _backend.set_data(path, key, data)
	
	if not success:
		Log.error("Failed to set data", {
			"collection": _collection_name,
			"key": key,
			"path": path,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_ERROR])
	else:
		Log.debug("Data set successfully", {
			"collection": _collection_name,
			"key": key,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB])
	
	return success

## Push data to the backend with proper error handling
## @param data The data to push
## @param custom_path Optional custom path to use instead of the collection's base path
## @return String The generated unique ID
func _push_data(data: Variant, custom_path: Array = []) -> String:
	var path: Array = custom_path if custom_path.size() > 0 else _get_path()
	
	Log.debug("Pushing data", {
		"collection": _collection_name,
		"path": path,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])
	
	var push_id: String = await _backend.push_data(path, data)
	
	if push_id.is_empty():
		Log.error("Failed to push data", {
			"collection": _collection_name,
			"path": path,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_ERROR])
	else:
		Log.debug("Data pushed successfully", {
			"collection": _collection_name,
			"push_id": push_id,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB])
	
	return push_id

## Remove data from the backend with proper error handling
## @param key The key to remove data for
## @param custom_path Optional custom path to use instead of the collection's base path
## @return bool True if data was removed successfully
func _remove_data(key: String, custom_path: Array = []) -> bool:
	var path: Array = custom_path if custom_path.size() > 0 else _get_path()
	
	Log.debug("Removing data", {
		"collection": _collection_name,
		"key": key,
		"path": path,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])
	
	var success: bool = await _backend.remove_data(path, key)
	
	if not success:
		Log.error("Failed to remove data", {
			"collection": _collection_name,
			"key": key,
			"path": path,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_ERROR])
	else:
		Log.debug("Data removed successfully", {
			"collection": _collection_name,
			"key": key,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB])
	
	return success

## Validate required fields in a data object
## @param data The data to validate
## @param required_fields Array of field names that must be present
## @return bool True if all required fields are present
func _validate_required_fields(data: Dictionary, required_fields: Array[String]) -> bool:
	var missing_fields: Array[String] = []
	
	for field in required_fields:
		if not data.has(field):
			missing_fields.append(field)
	
	if missing_fields.size() > 0:
		Log.error("Data missing required fields", {
			"collection": _collection_name,
			"missing_fields": missing_fields,
			"available_fields": data.keys(),
			"collection_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_ERROR])
		return false
	
	return true

## Helper to get a simplified stack trace for debugging
## @param depth Number of frames to include in the trace
## @return Array of simplified stack frame information
func _get_stack_trace(depth: int = 2) -> Array[Dictionary]:
	var stack: Array = get_stack()
	var simplified_stack: Array[Dictionary] = []
	
	for i in range(min(depth, stack.size())):
		if i >= stack.size():
			break
			
		var frame: Dictionary = stack[i]
		simplified_stack.append({
			"function": frame.function,
			"file": frame.source.get_file(),
			"line": frame.line
		})
	
	return simplified_stack

## Check if the backend being used is a Firebase backend
## @return bool True if using Firebase backend
func is_using_firebase() -> bool:
	return _backend is FirebaseBackend

## Check if the backend being used is a Local JSON backend
## @return bool True if using Local JSON backend
func is_using_local_json() -> bool:
	return _backend is LocalJSONBackend

## Get a value from the cache
## @param cache_key The cache key
## @param default_value The default value if key not found or expired
## @return The cached value or default_value
func _get_from_cache(cache_key: String, default_value: Variant = null) -> Variant:
	if not _is_caching_enabled():
		return default_value
		
	return _cache_manager.get(cache_key, default_value)

## Store a value in the cache
## @param cache_key The cache key
## @param value The value to cache
## @param ttl Optional TTL in seconds (0 = use default)
## @return void
func _store_in_cache(cache_key: String, value: Variant, ttl: int = 0) -> void:
	if not _is_caching_enabled():
		return
		
	_cache_manager.set(cache_key, value, ttl)

## Check if a value exists in the cache
## @param cache_key The cache key
## @return True if the value exists and is valid
func _has_in_cache(cache_key: String) -> bool:
	if not _is_caching_enabled():
		return false
		
	return _cache_manager.has(cache_key)

## Check if caching is enabled
## @return True if caching is enabled
func _is_caching_enabled() -> bool:
	if ProjectSettings.has_setting("gametwo/data/use_cache"):
		return ProjectSettings.get_setting("gametwo/data/use_cache")
	return true  # Default to enabled

## Clear the cache
## @param cache_key Optional specific cache key to clear (empty for all)
## @return void
func clear_cache(cache_key: String = "") -> void:
	if cache_key.is_empty():
		Log.info("Clearing all cache for collection", {
			"collection_name": _collection_name,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_CACHE])
		
		_cache_manager.clear()
	else:
		Log.info("Clearing specific cache entry", {
			"collection_name": _collection_name,
			"cache_key": cache_key,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_CACHE])
		
		_cache_manager.remove(cache_key)

## Clear expired cache entries
## @return void
func clear_expired_cache() -> void:
	var removed_count: int = _cache_manager.clear_expired()
	
	Log.info("Cleared expired cache entries", {
		"collection_name": _collection_name,
		"removed_count": removed_count,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB, Log.TAG_CACHE])

## Get cache statistics
## @return Dictionary with cache statistics
func get_cache_stats() -> Dictionary:
	var stats: Dictionary = _cache_manager.get_stats()
	stats["collection_name"] = _collection_name
	stats["collection_id"] = get_instance_id()
	
	return stats
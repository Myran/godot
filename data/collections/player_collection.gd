class_name PlayerCollection
extends BaseCollection

## Collection class for player data.
## Provides access to player information and save functionality.

# Cache of retrieved player data by UUID
var _cache: Dictionary = {}

# Whether any cache entries have been initialized
var _is_cache_initialized: bool = false

## Initialize the player collection with the backend
## @param backend The data backend to use
func _init(backend: DataBackend) -> void:
	super(backend, ["players"], "Players")
	Log.info("PlayerCollection initialized", {
		"collection_name": _collection_name,
		"backend_class": _backend.get_class(),
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])

## Get user data for a UUID
## @param uuid UUID of the player (if empty, uses current user from Auth)
## @param use_cache Whether to use the cache if available
## @return Dictionary containing player data
func get_user_data(uuid: String = "", use_cache: bool = true) -> Dictionary:
	# Resolve UUID if empty
	var resolved_uuid: String = _resolve_uuid(uuid)
	
	Log.info("Getting user data", {
		"specified_uuid": not uuid.is_empty(),
		"resolved_uuid": resolved_uuid,
		"use_cache": use_cache,
		"collection_name": _collection_name,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])
	
	# Use cache if available and requested
	if use_cache and _is_cache_initialized and _cache.has(resolved_uuid):
		Log.debug("Using cached player data", {
			"uuid": resolved_uuid,
			"collection_name": _collection_name,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_CACHE])
		return _cache[resolved_uuid]
	
	# Prepare path for data retrieval
	var path: Array = _get_path().duplicate()
	path.append(resolved_uuid)
	
	var request_start_time: int = Time.get_ticks_msec()
	var result: Variant = await _backend.get_data(path, "avatar_data")
	var request_duration: int = Time.get_ticks_msec() - request_start_time
	
	Log.debug("Backend get_data call completed", {
		"duration_ms": request_duration,
		"uuid": resolved_uuid,
		"result_null": result == null,
		"collection_name": _collection_name,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])
	
	# Handle case where result is null
	if result == null:
		Log.error("No player data returned", {
			"uuid": resolved_uuid,
			"path": path,
			"backend_class": _backend.get_class(),
			"collection_name": _collection_name,
			"collection_id": get_instance_id(),
			"stack_trace": _get_stack_trace(3)
		}, [Log.TAG_DB, Log.TAG_ERROR])
		
		push_error("Player data is missing for UUID: " + resolved_uuid)
		
		# Return default data for fallback
		var default_data: Dictionary = get_default_data()
		Log.warning("Using default player data as fallback", {
			"uuid": resolved_uuid,
			"collection_name": _collection_name,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_WARNING])
		
		# Store in cache
		_cache[resolved_uuid] = default_data
		_is_cache_initialized = true
		
		return default_data
	
	# If result is not a dictionary, try to extract player data using JSONPathNavigator
	if not (result is Dictionary):
		Log.warning("Player data is not a dictionary, attempting to navigate result", {
			"result_type": typeof(result),
			"uuid": resolved_uuid,
			"collection_name": _collection_name,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_WARNING])
		
		var nav_result: NavigationResult = JSONPathNavigator.navigate(result, [])
		if nav_result.is_dictionary():
			result = nav_result.as_dictionary()
		else:
			# Try common paths for player data
			var player_paths: Array = [["data"], ["player"], ["user"], ["avatar"]]
			
			for search_path in player_paths:
				var player_result: NavigationResult = JSONPathNavigator.navigate(result, search_path)
				if player_result.is_dictionary():
					Log.debug("Found player data at path", {
						"path": search_path,
						"uuid": resolved_uuid,
						"collection_name": _collection_name
					}, [Log.TAG_DB])
					result = player_result.as_dictionary()
					break
	
	if result is Dictionary:
		# Validate required fields
		_validate_player_data(result, resolved_uuid)
		
		# Store in cache
		_cache[resolved_uuid] = result
		_is_cache_initialized = true
		
		Log.debug("Retrieved user data", {
			"uuid": resolved_uuid,
			"field_count": result.keys().size(),
			"collection_name": _collection_name,
			"duration_ms": request_duration,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB])
		
		return result
	else:
		Log.error("Failed to process player data", {
			"result_type": typeof(result),
			"uuid": resolved_uuid,
			"collection_name": _collection_name,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_ERROR])
		
		# Return default data as fallback
		var default_data: Dictionary = get_default_data()
		_cache[resolved_uuid] = default_data
		_is_cache_initialized = true
		
		return default_data

## Save user data for the current user
## @param data Dictionary containing player data to save
## @return bool True if save was successful
func save_user_data(data: Dictionary) -> bool:
	Log.info("Saving user data", {
		"field_count": data.keys().size(),
		"collection_name": _collection_name,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])
	
	var auth: Object = Engine.get_singleton("Auth")
	if not auth or not auth.is_available():
		Log.error("Cannot save user data - auth not available", {
			"collection_name": _collection_name,
			"collection_id": get_instance_id(),
			"stack_trace": _get_stack_trace(3)
		}, [Log.TAG_DB, Log.TAG_ERROR])
		
		push_error("Auth not available when trying to save user data")
		return false
	
	var uuid: String = auth.uid()
	var path: Array = _get_path().duplicate()
	path.append(uuid)
	
	# Validate data before saving
	_validate_player_data(data, uuid)
	
	var request_start_time: int = Time.get_ticks_msec()
	var success: bool = await _backend.set_data(path, "avatar_data", data)
	var request_duration: int = Time.get_ticks_msec() - request_start_time
	
	if success:
		Log.info("User data saved successfully", {
			"uuid": uuid,
			"duration_ms": request_duration,
			"collection_name": _collection_name,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB])
		
		# Update cache
		_cache[uuid] = data.duplicate()
		_is_cache_initialized = true
	else:
		Log.error("Failed to save user data", {
			"uuid": uuid,
			"collection_name": _collection_name,
			"collection_id": get_instance_id(),
			"stack_trace": _get_stack_trace(3)
		}, [Log.TAG_DB, Log.TAG_ERROR])
		
	return success

## Get default player data structure
## @return Dictionary with default player data
func get_default_data() -> Dictionary:
	var data: Dictionary = {
		"progress": 1,
		"sfx": true,
		"music": false,
		"vibrate": true,
		"notification": false,
		"name": "test_avatar_name",
		"id": "1",
		"level": 1,
		"experience": 0,
		"coins": 100,
		"items": [],
		"created_at": Time.get_unix_time_from_system()
	}
	
	Log.debug("Generated default player data", {
		"field_count": data.keys().size(),
		"collection_name": _collection_name,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])
	
	return data

## Clear the player cache
## @param uuid Optional UUID to clear from cache (if empty, clears all cache)
## @return void
func clear_cache(uuid: String = "") -> void:
	if uuid.is_empty():
		Log.info("Clearing all player cache", {
			"cache_size": _cache.size(),
			"collection_name": _collection_name,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_CACHE])
		
		_cache.clear()
		_is_cache_initialized = false
	else:
		Log.info("Clearing player cache for UUID", {
			"uuid": uuid,
			"collection_name": _collection_name,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_CACHE])
		
		if _cache.has(uuid):
			_cache.erase(uuid)
			
		# If cache is now empty, set initialized to false
		if _cache.is_empty():
			_is_cache_initialized = false

## Helper to get a simplified stack trace for debugging
## @param depth Number of frames to include in the trace
## @return Array of simplified stack frame information
func _get_stack_trace(depth: int = 2) -> Array:
	var stack: Array = get_stack()
	var simplified_stack: Array = []
	
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

## Helper function to resolve UUID
## @param uuid UUID to resolve (if empty, uses current user from Auth)
## @return Resolved UUID string
func _resolve_uuid(uuid: String) -> String:
	if not uuid.is_empty():
		return uuid
		
	var auth: Object = Engine.get_singleton("Auth")
	if auth and auth.is_available():
		var resolved_uuid: String = auth.uid()
		Log.debug("Using auth UUID", {"uuid": resolved_uuid}, [Log.TAG_DB])
		return resolved_uuid
	else:
		Log.debug("Auth not available, using default UUID", {}, [Log.TAG_DB])
		return "0"

## Validate player data for required fields
## @param data Player data to validate
## @param uuid UUID associated with the player data
## @return void
func _validate_player_data(data: Dictionary, uuid: String) -> void:
	var required_fields: Array = ["name", "id"]
	var missing_fields: Array = []
	
	for field in required_fields:
		if not data.has(field):
			missing_fields.append(field)
	
	if missing_fields.size() > 0:
		Log.warning("Player data missing required fields", {
			"missing_fields": missing_fields,
			"available_fields": data.keys(),
			"uuid": uuid,
			"collection_name": _collection_name,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_WARNING])
		
		# Add missing fields with default values
		if "name" in missing_fields:
			data["name"] = "Player_" + uuid.substr(0, 4)
		
		if "id" in missing_fields:
			data["id"] = uuid

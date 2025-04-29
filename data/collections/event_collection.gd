class_name EventCollection
extends BaseCollection

# Import class references directly
const JSONPathNavigatorClass = preload("res://data/backends/json_path_navigator.gd") 
const NavigationResultClass = preload("res://data/backends/navigation_result.gd")

## Collection class for event data.
## Provides access to event information and lineup management.

# Key for retrieving event data
var _collection_key: String = ""

# Cache of retrieved events
var _cache: Array = []

# Whether the cache has been initialized
var _is_cache_initialized: bool = false

# Cache of lineups by event ID
var _lineup_cache: Dictionary = {}

## Initialize the event collection with the backend
## @param backend The data backend to use
## @param test_group The test group suffix to use
func _init(backend: DataBackend, test_group: int = 0) -> void:
	super(backend, ["sheets"], "Events")
	_collection_key = "event_data_" + str(test_group)
	Log.info("EventCollection initialized", {
		"test_group": test_group,
		"collection_name": _collection_name,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])
	
## Get all events
## @param use_cache Whether to use the cache if available
## @return Array of event dictionaries
func get_all(use_cache: bool = true) -> Array:
	if use_cache and _is_cache_initialized:
		Log.debug("Using event cache", {
			"cache_size": _cache.size(),
			"collection_name": _collection_name,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_CACHE])
		return _cache
		
	Log.info("Getting event data", {
		"use_cache": use_cache,
		"cache_initialized": _is_cache_initialized,
		"collection_name": _collection_name,
		"collection_key": _collection_key,
		"base_path": _base_path,
		"collection_id": get_instance_id(),
		"stack_trace": _get_stack_trace(2)
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
		Log.error("No event data returned", {
			"collection_name": _collection_name,
			"collection_key": _collection_key,
			"base_path": _base_path,
			"backend_class": _backend.get_class(),
			"collection_id": get_instance_id(),
			"stack_trace": _get_stack_trace(3)
		}, [Log.TAG_DB, Log.TAG_ERROR])
		
		push_error("Required event data is missing for collection: " + _collection_name + " with key: " + _collection_key)
		
		# For editor testing, create minimal test events
		var test_events: Array = []
		for i in range(3):
			var event_id: String = "event_" + str(i)
			test_events.append({
				"id": event_id,
				"name": "Test Event " + str(i),
				"description": "Test event description",
				"start_date": Time.get_unix_time_from_system(),
				"end_date": Time.get_unix_time_from_system() + 86400, # Next day
				"type": "tournament",
				"rewards": {
					"first_place": ["gold_badge", 1000],
					"participation": ["bronze_badge", 100]
				},
				"requirements": {
					"player_level": i + 1
				}
			})
			
		Log.warning("Using emergency test events for editor testing ONLY", {
			"count": test_events.size(),
			"collection_name": _collection_name,
			"collection_id": get_instance_id(),
			"emergency_data": true
		}, [Log.TAG_DB])
		
		_cache = test_events
	else:
		Log.debug("Processing event data result", {
			"result_type": typeof(result),
			"is_array": result is Array,
			"result_size": result.size() if result is Array else 0,
			"collection_name": _collection_name,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB])
		
		# Use JSONPathNavigator for safe handling if result is not already an array
		if not (result is Array):
			Log.warning("Event data is not an array, attempting to navigate result", {
				"collection_name": _collection_name,
				"result_type": typeof(result),
				"collection_id": get_instance_id()
			}, [Log.TAG_DB, Log.TAG_WARNING])
			
			var nav_result: NavigationResultClass = JSONPathNavigatorClass.navigate(result, [])
			if nav_result.is_array():
				result = nav_result.as_array()
			elif nav_result.is_dictionary():
				# Try to extract events from dictionary structure
				var events_result: NavigationResultClass = JSONPathNavigatorClass.navigate(nav_result.value, ["events"])
				if events_result.is_array():
					result = events_result.as_array()
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
			Log.error("Failed to process event data", {
				"collection_name": _collection_name,
				"result_type": typeof(result),
				"collection_id": get_instance_id()
			}, [Log.TAG_DB, Log.TAG_ERROR])
			_cache = []
	
	_is_cache_initialized = true
	
	# Log detailed results
	Log.info("Retrieved all events", {
		"count": _cache.size(),
		"collection_name": _collection_name,
		"collection_key": _collection_key,
		"empty_result": _cache.size() == 0,
		"duration_ms": request_duration,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])
	
	return _cache

## Get event by ID
## @param event_id The ID of the event to retrieve
## @param use_cache Whether to use the cache if available
## @return Event dictionary or empty dictionary if not found
func get_by_id(event_id: String, use_cache: bool = true) -> Dictionary:
	Log.info("Getting event by ID", {"event_id": event_id, "use_cache": use_cache}, [Log.TAG_DB])
	
	var events: Array = await get_all(use_cache)
	
	for event in events:
		if not event is Dictionary:
			continue
			
		var event_dict: Dictionary = event
		if not event_dict.has("id"):
			continue
			
		var id: String = str(event_dict.id)
		if id == event_id:
			Log.debug("Event found", {"event_id": event_id}, [Log.TAG_DB])
			return event_dict
	
	Log.error("Event with ID not found", {"event_id": event_id}, [Log.TAG_DB, Log.TAG_ERROR])
	return {}

## Get events by type
## @param event_type The type of events to retrieve
## @param use_cache Whether to use the cache if available
## @return Array of event dictionaries matching the type
func get_by_type(event_type: String, use_cache: bool = true) -> Array:
	Log.info("Getting events by type", {"event_type": event_type, "use_cache": use_cache}, [Log.TAG_DB])
	
	var events: Array = await get_all(use_cache)
	var filtered_events: Array = []
	
	for event in events:
		if not event is Dictionary:
			continue
			
		var event_dict: Dictionary = event
		if not event_dict.has("type"):
			continue
			
		if event_dict.type == event_type:
			filtered_events.append(event_dict)
	
	Log.debug("Found events by type", {"event_type": event_type, "count": filtered_events.size()}, [Log.TAG_DB])
	return filtered_events

## Get active events (current date is between start_date and end_date)
## @param use_cache Whether to use the cache if available
## @return Array of active event dictionaries
func get_active_events(use_cache: bool = true) -> Array:
	Log.info("Getting active events", {"use_cache": use_cache}, [Log.TAG_DB])
	
	var events: Array = await get_all(use_cache)
	var active_events: Array = []
	var current_time: int = Time.get_unix_time_from_system()
	
	for event in events:
		if not event is Dictionary:
			continue
			
		var event_dict: Dictionary = event
		if not (event_dict.has("start_date") and event_dict.has("end_date")):
			continue
			
		var start_date: int
		var end_date: int
		
		# Parse dates if they're strings
		if event_dict.start_date is String and event_dict.start_date.is_valid_int():
			start_date = event_dict.start_date.to_int()
		elif event_dict.start_date is int or event_dict.start_date is float:
			start_date = int(event_dict.start_date)
		else:
			continue
			
		if event_dict.end_date is String and event_dict.end_date.is_valid_int():
			end_date = event_dict.end_date.to_int()
		elif event_dict.end_date is int or event_dict.end_date is float:
			end_date = int(event_dict.end_date)
		else:
			continue
			
		if current_time >= start_date and current_time <= end_date:
			active_events.append(event_dict)
	
	Log.debug("Found active events", {"count": active_events.size()}, [Log.TAG_DB])
	return active_events
	
## Get lineup data for an event
## @param event_id Event ID to get lineups for
## @param use_cache Whether to use the cache if available
## @return Dictionary containing lineup data
func get_lineup_data(event_id: String, use_cache: bool = true) -> Dictionary:
	Log.info("Getting event lineups data", {"event_id": event_id, "use_cache": use_cache}, [Log.TAG_DB])
	
	if use_cache and _lineup_cache.has(event_id):
		Log.debug("Using cached lineup data", {"event_id": event_id}, [Log.TAG_DB, Log.TAG_CACHE])
		return _lineup_cache[event_id]
	
	if not _backend.is_available():
		Log.error("Database not available for getting event lineups", {
			"event_id": event_id,
			"collection_name": _collection_name,
			"collection_id": get_instance_id(),
			"stack_trace": _get_stack_trace(3)
		}, [Log.TAG_DB, Log.TAG_ERROR])
		return {}
		
	var path: Array = ["events", event_id]
	
	var request_start_time: int = Time.get_ticks_msec()
	var result: Variant = await _backend.get_data(path, "lineups")
	var request_duration: int = Time.get_ticks_msec() - request_start_time
	
	if result == null:
		Log.error("No lineup data returned", {
			"event_id": event_id,
			"path": path,
			"collection_name": _collection_name,
			"collection_id": get_instance_id(),
			"stack_trace": _get_stack_trace(3)
		}, [Log.TAG_DB, Log.TAG_ERROR])
		return {}
	
	if result is Dictionary:
		# Store in cache
		_lineup_cache[event_id] = result
		
		Log.debug("Retrieved event lineup data", {
			"event_id": event_id,
			"lineup_count": result.size(),
			"duration_ms": request_duration,
			"collection_name": _collection_name,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB])
		
		return result
	else:
		Log.error("Lineup data is not a dictionary", {
			"event_id": event_id,
			"result_type": typeof(result),
			"collection_name": _collection_name,
			"collection_id": get_instance_id(),
			"stack_trace": _get_stack_trace(3)
		}, [Log.TAG_DB, Log.TAG_ERROR])
		return {}
	
## Save lineup data for an event
## @param event_id Event ID to save lineup for
## @param lineup Lineup data to save
## @param level Level number for the lineup
## @param p_data Player data to include
## @param lives Number of lives
## @param lineup_uuid Existing lineup ID (if updating existing lineup)
## @return String Lineup ID
func save_lineup_data(
	event_id: String,
	lineup: Dictionary,
	level: int = 1,
	p_data: Dictionary = {},
	lives: int = 3,
	lineup_uuid: String = ""
) -> String:
	Log.info("Saving event lineup data", {
		"event_id": event_id, 
		"level": level, 
		"lives": lives,
		"is_update": not lineup_uuid.is_empty(),
		"collection_name": _collection_name,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])
	
	if not _backend.is_available():
		Log.error("Cannot save event lineup - database not available", {
			"event_id": event_id,
			"collection_name": _collection_name,
			"collection_id": get_instance_id(),
			"stack_trace": _get_stack_trace(3)
		}, [Log.TAG_DB, Log.TAG_ERROR])
		return ""
		
	var json_data: String = JSON.stringify(lineup)
	var path: Array = ["events", event_id, "lineups"]
	
	var data: Dictionary = {
		"lineup_level": level, 
		"lineup_data": json_data, 
		"lives": lives,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	if not p_data.is_empty():
		if p_data.has("name"):
			data["name"] = p_data.name
			
		if p_data.has("avatar_id"):
			data["avatar_id"] = p_data.avatar_id
		elif p_data.has("id"):
			data["avatar_id"] = p_data.id
	
	var push_id: String
	var request_start_time: int = Time.get_ticks_msec()
	
	if lineup_uuid.is_empty():
		push_id = await _backend.push_data(path, data)
	else:
		push_id = lineup_uuid
		var update_path: Array = ["events", event_id, "lineups"]
		await _backend.set_data(update_path, push_id, data)
	
	var request_duration: int = Time.get_ticks_msec() - request_start_time
		
	Log.debug("Event lineup saved", {
		"event_id": event_id, 
		"lineup_id": push_id,
		"duration_ms": request_duration,
		"collection_name": _collection_name,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])
	
	# Clear cache for this event
	if _lineup_cache.has(event_id):
		_lineup_cache.erase(event_id)
	
	return push_id
	
## Remove lineups from an event
## @param event_id Event ID to remove lineups from
## @return bool True if removal was successful
func remove_event_lineups(event_id: String) -> bool:
	Log.info("Removing event lineups", {
		"event_id": event_id,
		"collection_name": _collection_name,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB])
	
	if not _backend.is_available():
		Log.error("Cannot remove event lineups - database not available", {
			"event_id": event_id,
			"collection_name": _collection_name,
			"collection_id": get_instance_id(),
			"stack_trace": _get_stack_trace(3)
		}, [Log.TAG_DB, Log.TAG_ERROR])
		return false
		
	var path: Array = ["events", event_id]
	
	var request_start_time: int = Time.get_ticks_msec()
	var success: bool = await _backend.remove_data(path, "lineups")
	var request_duration: int = Time.get_ticks_msec() - request_start_time
	
	if success:
		Log.info("Event lineups removed successfully", {
			"event_id": event_id,
			"duration_ms": request_duration,
			"collection_name": _collection_name,
			"collection_id": get_instance_id()
		}, [Log.TAG_DB])
		
		# Clear cache for this event
		if _lineup_cache.has(event_id):
			_lineup_cache.erase(event_id)
	else:
		Log.error("Failed to remove event lineups", {
			"event_id": event_id,
			"collection_name": _collection_name,
			"collection_id": get_instance_id(),
			"stack_trace": _get_stack_trace(3)
		}, [Log.TAG_DB, Log.TAG_ERROR])
	
	return success

## Clear the event cache
## @return void
func clear_cache() -> void:
	Log.info("Clearing event cache", {
		"cache_size": _cache.size(),
		"lineup_cache_size": _lineup_cache.size(),
		"collection_name": _collection_name,
		"collection_id": get_instance_id()
	}, [Log.TAG_DB, Log.TAG_CACHE])
	
	_is_cache_initialized = false
	_cache = []
	_lineup_cache.clear()

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

class_name EventCollection
extends BaseCollection

var _collection_key: String = ""

## Initialize the event collection with the backend
## @param backend The data backend to use
## @param test_group The test group suffix to use
func _init(backend: DataBackend, test_group: int = 0):
	super(backend, ["sheets"], "Events")
	_collection_key = "event_data_" + str(test_group)
	Log.info("EventCollection initialized", {"test_group": test_group}, [Log.TAG_DB])
	
## Get all events
## @return Array of event dictionaries
func get_all() -> Array:
	Log.info("Getting event data", {}, [Log.TAG_DB])
	var result = await _backend.get_data(_get_path(), _collection_key)
	
	# Handle case where result is null
	if result == null:
		Log.warning("No event data returned, using empty array", {}, [Log.TAG_DB, Log.TAG_ERROR])
		return []
	
	return result
	
## Get lineup data for an event
## @param event Event ID to get lineups for
## @return Dictionary containing lineup data
func get_lineup_data(event: String) -> Dictionary:
	Log.info("Getting event lineups data", {"event": event}, [Log.TAG_DB])
	
	if not _backend.is_available():
		Log.error("Database not available for getting event lineups", {}, [Log.TAG_DB, Log.TAG_ERROR])
		return {}
		
	var path = ["events", event]
	return await _backend.get_data(path, "lineups")
	
## Save lineup data for an event
## @param event Event ID to save lineup for
## @param lineup Lineup data to save
## @param level Level number for the lineup
## @param p_data Player data to include
## @param lives Number of lives
## @param lineup_uuid Existing lineup ID (if updating existing lineup)
## @return String Lineup ID
func save_lineup_data(
	event: String,
	lineup: Dictionary,
	level: int = 1,
	p_data: Dictionary = {},
	lives: int = 3,
	lineup_uuid: String = ""
) -> String:
	Log.info("Saving event lineup data", {"event": event, "level": level, "lives": lives}, [Log.TAG_DB])
	
	if not _backend.is_available():
		Log.error("Cannot save event lineup - database not available", {}, [Log.TAG_DB, Log.TAG_ERROR])
		return ""
		
	var json_data = JSON.stringify(lineup)
	var path = ["events", event, "lineups"]
	
	var data = {
		"lineup_level": level, 
		"lineup_data": json_data, 
		"lives": lives
	}
	
	if not p_data.is_empty():
		data.name = p_data.name
		data.avatar_id = p_data.avatar_id
		
	var push_id
	if lineup_uuid.is_empty():
		push_id = await _backend.push_data(path, data)
	else:
		push_id = lineup_uuid
		var update_path = ["events", event, "lineups"]
		await _backend.set_data(update_path, push_id, data)
		
	Log.debug("Event lineup saved", {"event": event, "lineup_id": push_id}, [Log.TAG_DB])
	return push_id
	
## Remove lineups from an event
## @param event Event ID to remove lineups from
## @return bool True if removal was successful
func remove_event_lineups(event: String) -> bool:
	Log.info("Removing event lineups", {"event": event}, [Log.TAG_DB])
	
	if not _backend.is_available():
		Log.error("Cannot remove event lineups - database not available", {}, [Log.TAG_DB, Log.TAG_ERROR])
		return false
		
	var path = ["events", event]
	return await _backend.remove_data(path, "lineups")
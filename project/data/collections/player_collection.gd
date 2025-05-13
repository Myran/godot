class_name PlayerCollection
extends BaseCollection


## Initialize the player collection with the backend
## @param backend The data backend to use
func _init(backend: DataBackend) -> void:
	super(backend, ["players"], "players")
	Log.info("PlayerCollection initialized", {}, [Log.TAG_DB])


## Get user data for a UUID
## @param uuid UUID of the player (if empty, uses current user from Auth)
## @return Dictionary containing player data
func get_user_data(uuid: String = "") -> Dictionary:
	Log.info("Getting user data", {"specified_uuid": not uuid.is_empty()}, [Log.TAG_DB])

	if uuid.is_empty():
		var auth: Object = Engine.get_singleton("Auth")
		if auth and auth.is_available():
			uuid = auth.uid()
			Log.debug("Using auth UUID", {"uuid": uuid}, [Log.TAG_DB])
		else:
			uuid = "0"
			Log.debug("Auth not available, using default UUID", {}, [Log.TAG_DB])

	var path: Array[Variant] = _get_path().duplicate()
	path.append(uuid)
	var result: Dictionary = {}
	var data: Variant = await _backend.get_data(path, "avatar_data")
	if data is Dictionary:
		result = data

	Log.debug("Retrieved user data", {"uuid": uuid}, [Log.TAG_DB])
	return result


## Save user data for the current user
## @param data Dictionary containing player data to save
## @return bool True if save was successful
func save_user_data(data: Dictionary) -> bool:
	Log.info("Saving user data", {}, [Log.TAG_DB])

	var auth: Object = Engine.get_singleton("Auth")
	if not auth or not auth.is_available():
		Log.error("Cannot save user data - auth not available", {}, [Log.TAG_DB, Log.TAG_ERROR])
		return false

	var uuid: String = auth.uid()
	var path: Array[Variant] = _get_path().duplicate()
	path.append(uuid)

	@warning_ignore("redundant_await")
	return await _backend.set_data(path, "avatar_data", data)


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
		"id": "1"
	}

	Log.debug("Generated default player data", {}, [Log.TAG_DB])
	return data

class_name LoadDebugStateAction extends DebugAction

var _file_path: String = ""


func _init(file_path: String = "") -> void:
	_file_path = file_path
	super("system.debug.load_gamestate", _execute_load_gamestate)
	set_category("System")
	set_group("Debug")
	set_description("Load saved debug gamestate as recording session starting point")
	use_auto_semantic_logging = false  # Opt out - we handle specialized logging with domain-specific data


func _execute_load_gamestate() -> DebugAction.Result:
	var actual_file_path: String = _file_path

	# If no specific file path provided, check debug config metadata first
	if actual_file_path.is_empty():
		var metadata: Dictionary = DebugConfigReader.get_metadata()
		var gamestate_filename: String = metadata.get("gamestate_file", "")

		if not gamestate_filename.is_empty():
			# Construct full path from filename using centralized path management
			actual_file_path = DebugConfigReader.get_saved_state_path(gamestate_filename)
			Log.info(
				"Using gamestate file from config metadata",
				{"filename": gamestate_filename, "full_path": actual_file_path},
				[Log.TAG_DEBUG, "gamestate"]
			)
		else:
			# Fall back to finding most recent saved state
			actual_file_path = _find_most_recent_saved_state()
			if actual_file_path.is_empty():
				return DebugAction.Result.new_failure(
					"No saved state files found and no file path provided"
				)

	var start_time: int = Time.get_ticks_msec()

	Log.info(
		"Loading gamestate via restart system",
		{"file_path": actual_file_path},
		[Log.TAG_DEBUG, "gamestate"]
	)

	# Read and validate JSON file
	var file: FileAccess = FileAccess.open(actual_file_path, FileAccess.READ)
	if not file:
		return DebugAction.Result.new_failure("Cannot open file: " + actual_file_path)

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)
	if parse_result != OK:
		return DebugAction.Result.new_failure("Invalid JSON in file: " + _file_path)

	var capture_data: Variant = json.data

	# Validate capture data structure
	if not _validate_capture_data(capture_data):
		return DebugAction.Result.new_failure("Invalid capture data format")

	var capture_dict: Dictionary = capture_data as Dictionary

	# Load gamestate using Game's direct loading method
	var game_instance: Game = _get_game_instance()
	if not game_instance:
		return DebugAction.Result.new_failure("Game instance not found")

	var restoration_success: bool = await game_instance.load_state_from_file(actual_file_path)

	if not restoration_success:
		return DebugAction.Result.new_failure("Failed to load gamestate from file")

	# Log the load request
	SessionManager.log_semantic_action(
		"system.debug.load_gamestate",
		{
			"file": actual_file_path.get_file(),
			"original_capture_id": capture_dict.get("capture_id", "unknown"),
			"original_timestamp": capture_dict.get("capture_timestamp", "unknown"),
			"load_method": "in_place_restoration",
			"restored_state":
			capture_dict.get("gamestate", {}).get("lineup", {}).get("current_game_state", "UNKNOWN")
		}
	)

	var duration: int = Time.get_ticks_msec() - start_time

	return DebugAction.Result.new_success(
		{
			"message": "Gamestate restored in current session",
			"gamestate_file": actual_file_path.get_file(),
			"original_capture_id": capture_dict.get("capture_id", "unknown"),
			"restored_state":
			capture_dict.get("gamestate", {}).get("lineup", {}).get(
				"current_game_state", "UNKNOWN"
			),
			"load_method": "in_place_restoration"
		},
		duration
	)


func _validate_capture_data(data: Variant) -> bool:
	if not data is Dictionary:
		return false

	var data_dict: Dictionary = data as Dictionary
	return (
		data_dict.has("gamestate")
		and data_dict.has("rng_state")
		and data_dict.has("capture_timestamp")
	)


func _get_game_instance() -> Game:
	"""Get the current Game instance"""
	var main_loop: SceneTree = Engine.get_main_loop()
	if not main_loop:
		return null
	var current_scene: Node = main_loop.current_scene
	if current_scene and current_scene.has_node("Game"):
		return current_scene.get_node("Game") as Game
	return null


func _find_most_recent_saved_state() -> String:
	"""Find the most recently created saved state file"""
	var saved_states_dir: String = DebugConfigReader.get_saved_states_dir()
	var dir: DirAccess = DirAccess.open(saved_states_dir)

	if not dir:
		Log.warning(
			"Cannot access saved states directory",
			{"dir": saved_states_dir},
			[Log.TAG_DEBUG, "gamestate"]
		)
		return ""

	var files: PackedStringArray = dir.get_files()
	var json_files: Array[String] = []

	# Filter for JSON files
	for file: String in files:
		if file.ends_with(".json"):
			json_files.append(file)

	if json_files.is_empty():
		Log.warning(
			"No saved state JSON files found",
			{"dir": saved_states_dir},
			[Log.TAG_DEBUG, "gamestate"]
		)
		return ""

	# Sort by modification time (most recent first)
	var file_times: Array[Dictionary] = []
	for file: String in json_files:
		var full_path: String = saved_states_dir + file
		var modified_time: int = FileAccess.get_modified_time(full_path)
		file_times.append({"file": file, "time": modified_time, "path": full_path})

	# Sort by time (newest first)
	file_times.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time > b.time)

	var most_recent: String = file_times[0].path
	Log.info(
		"Found most recent saved state",
		{"file": most_recent, "total_files": json_files.size()},
		[Log.TAG_DEBUG, "gamestate"]
	)

	return most_recent


static func create_for_file(file_path: String) -> LoadDebugStateAction:
	"""Create a LoadDebugStateAction with a specific file path"""
	return LoadDebugStateAction.new(file_path)

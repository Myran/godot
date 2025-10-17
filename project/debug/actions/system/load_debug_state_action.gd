class_name LoadDebugStateAction extends DebugAction

var _file_path: String = ""


func _init(file_path: String = "") -> void:
	_file_path = file_path
	super("system.debug.load_gamestate", _execute_load_gamestate)
	set_category("System")
	set_group("Debug")
	set_description("Load saved debug gamestate as recording session starting point")


func _execute_load_gamestate(params: Dictionary = {}) -> DebugActionResult:
	var actual_file_path: String = _file_path

	# Check for file parameter in params first (support both "file" and "filepath")
	var filename: String = ""
	if params.has("file") and not params["file"].is_empty():
		filename = params["file"]
	elif params.has("filepath") and not params["filepath"].is_empty():
		filename = params["filepath"]

	if not filename.is_empty():
		# Use appropriate path resolution based on file type
		if filename.begins_with("pending_"):
			# Temporary files created by startup system go to user:// directory
			actual_file_path = DebugConfigReader.get_temp_gamestate_path(filename)
			Log.info(
				"Using temporary gamestate file from action parameters",
				{"filename": filename, "full_path": actual_file_path, "file_type": "temporary"},
				[Log.TAG_DEBUG, "gamestate"]
			)
		else:
			# Regular saved states go to res://debug/saved_states/ directory
			actual_file_path = DebugConfigReader.get_saved_state_path(filename)
			Log.info(
				"Using permanent gamestate file from action parameters",
				{"filename": filename, "full_path": actual_file_path, "file_type": "permanent"},
				[Log.TAG_DEBUG, "gamestate"]
			)

	# If no specific file path provided, check debug config metadata next
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
				return DebugActionResult.new_failure(
					"No saved state files found and no file path provided"
				)

	# Simple timing approach to avoid formatter issues
	var start_time: int = Time.get_ticks_msec()

	Log.info(
		"Loading gamestate via restart system",
		{"file_path": actual_file_path},
		[Log.TAG_DEBUG, "gamestate"]
	)

	# Read and validate JSON file
	var file: FileAccess = FileAccess.open(actual_file_path, FileAccess.READ)
	if not file:
		return TestUtils.make_failure_result(
			"Cannot open file: " + actual_file_path,
			TestConstants.ERROR_CODES.FILE_READ_FAILED,
			0,
			action_name,
			TestUtils.make_metadata(TestConstants.TEST_TYPES.SYSTEM_LOAD_GAMESTATE)
		)

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)
	if parse_result != OK:
		return TestUtils.make_failure_result(
			"Invalid JSON in file: " + _file_path,
			TestConstants.ERROR_CODES.FILE_READ_FAILED,
			Time.get_ticks_msec() - start_time,
			action_name,
			TestUtils.make_metadata(TestConstants.TEST_TYPES.SYSTEM_LOAD_GAMESTATE)
		)

	var capture_data: Variant = json.data

	# Validate capture data structure
	if not _validate_capture_data(capture_data):
		return TestUtils.make_failure_result(
			"Invalid capture data format",
			TestConstants.ERROR_CODES.VALIDATION_FAILED,
			Time.get_ticks_msec() - start_time,
			action_name,
			TestUtils.make_metadata(TestConstants.TEST_TYPES.SYSTEM_LOAD_GAMESTATE)
		)

	var capture_dict: Dictionary = capture_data

	# Load gamestate using Game's direct loading method
	var game_instance: Game = _get_game_instance()
	if not game_instance:
		return TestUtils.make_failure_result(
			"Game instance not found",
			TestConstants.ERROR_CODES.VALIDATION_FAILED,
			Time.get_ticks_msec() - start_time,
			action_name,
			TestUtils.make_metadata(TestConstants.TEST_TYPES.SYSTEM_LOAD_GAMESTATE)
		)

	# Determine the appropriate loading method based on save type
	var restoration_success: bool = false

	if capture_dict.has("gamestate"):
		# Full gamestate save - use the standard loading method
		Log.debug(
			"Loading full gamestate via Game.load_state_from_file",
			{"file": actual_file_path},
			[Log.TAG_DEBUG, "gamestate", "load_action"]
		)
		restoration_success = await game_instance.load_state_from_file(actual_file_path)
	elif capture_dict.has("lineup_data"):
		# Lineup-only save - use the lineup loading method
		Log.debug(
			"Loading lineup-only save via lineup restoration",
			{"file": actual_file_path},
			[Log.TAG_DEBUG, "gamestate", "load_action"]
		)
		var lineup_data_dict: Dictionary = capture_dict.lineup_data
		restoration_success = await _load_lineup_only_data(game_instance, lineup_data_dict)
	else:
		return TestUtils.make_failure_result(
			"Unknown save format - neither gamestate nor lineup_data found",
			TestConstants.ERROR_CODES.VALIDATION_FAILED,
			Time.get_ticks_msec() - start_time,
			action_name,
			TestUtils.make_metadata(TestConstants.TEST_TYPES.SYSTEM_LOAD_GAMESTATE)
		)

	Log.debug(
		"Gamestate/lineup load completed",
		{
			"success": restoration_success,
			"save_type": "full_gamestate" if capture_dict.has("gamestate") else "lineup_only"
		},
		[Log.TAG_DEBUG, "gamestate", "load_action"]
	)

	if not restoration_success:
		return TestUtils.make_failure_result(
			"Failed to load gamestate from file",
			TestConstants.ERROR_CODES.FILE_READ_FAILED,
			Time.get_ticks_msec() - start_time,
			action_name,
			TestUtils.make_metadata(TestConstants.TEST_TYPES.SYSTEM_LOAD_GAMESTATE)
		)

	# Log the load request with detailed metadata
	Log.info(
		"Gamestate loaded successfully",
		{
			"file": actual_file_path.get_file(),
			"original_capture_id": capture_dict.get("capture_id", "unknown"),
			"original_timestamp": capture_dict.get("capture_timestamp", "unknown"),
			"load_method": "in_place_restoration",
			"restored_state":
			capture_dict.get("gamestate", {}).get("lineup", {}).get("current_game_state", "UNKNOWN")
		},
		[Log.TAG_DEBUG, "gamestate", "load_action"]
	)

	var total_duration: int = Time.get_ticks_msec() - start_time

	return TestUtils.make_success_result(
		"Gamestate restored in current session",
		total_duration,
		action_name,
		TestUtils.make_metadata(
			TestConstants.TEST_TYPES.SYSTEM_LOAD_GAMESTATE,
			{
				"gamestate_file": actual_file_path.get_file(),
				"original_capture_id": capture_dict.get("capture_id", "unknown"),
				"restored_state":
				capture_dict.get("gamestate", {}).get("lineup", {}).get(
					"current_game_state", "UNKNOWN"
				),
				"load_method": "in_place_restoration"
			}
		)
	)


func _validate_capture_data(data: Variant) -> bool:
	if not data is Dictionary:
		return false

	var data_dict: Dictionary = data

	# Handle both lineup-specific saves and full gamestate saves (following proven pattern from LoadAlliedLineupAction)
	var has_full_gamestate: bool = (
		data_dict.has("gamestate")
		and data_dict.has("rng_state")
		and data_dict.has("capture_timestamp")
	)

	var has_lineup_only: bool = data_dict.has("lineup_data") and data_dict.has("capture_timestamp")

	if has_full_gamestate:
		Log.debug(
			"Validated full gamestate format",
			{"save_type": "full_gamestate"},
			[Log.TAG_DEBUG, "gamestate", "validation"]
		)
		return true

	if has_lineup_only:
		Log.debug(
			"Validated lineup-only format - will load using lineup data",
			{"save_type": "lineup_only"},
			[Log.TAG_DEBUG, "gamestate", "validation"]
		)
		return true

	Log.error(
		"Invalid capture data format - missing required fields",
		{
			"has_gamestate": data_dict.has("gamestate"),
			"has_lineup_data": data_dict.has("lineup_data"),
			"has_rng_state": data_dict.has("rng_state"),
			"has_capture_timestamp": data_dict.has("capture_timestamp")
		},
		[Log.TAG_DEBUG, "gamestate", "validation"]
	)
	return false


func _load_lineup_only_data(game: Game, lineup_data: Dictionary) -> bool:
	"""Load lineup-only data using proven lineup loading methods"""
	Log.info(
		"Loading lineup-only data as partial gamestate restoration",
		{"lineup_data_keys": lineup_data.keys()},
		[Log.TAG_DEBUG, "gamestate", "lineup_only"]
	)

	# Use the same surgical replacement approach as LoadAlliedLineupAction
	if not game.holder_allies or not game.holder_enemy:
		Log.error(
			"Holder containers not available for lineup loading",
			{"has_allies": game.holder_allies != null, "has_enemies": game.holder_enemy != null},
			[Log.TAG_DEBUG, "gamestate", "lineup_only", "error"]
		)
		return false

	# Clear existing lineups (following LoadAlliedLineupAction pattern)
	var allies_cleared: int = GamestateLoader._clear_holder_container(game.holder_allies)
	var enemies_cleared: int = GamestateLoader._clear_holder_container(game.holder_enemy)

	Log.debug(
		"Cleared existing lineups for lineup-only restoration",
		{"allies_cleared": allies_cleared, "enemies_cleared": enemies_cleared},
		[Log.TAG_DEBUG, "gamestate", "lineup_only"]
	)

	# Restore lineup data (following LoadAlliedLineupAction pattern)
	var restoration_success: bool = true

	if lineup_data.has("allies") and not lineup_data.allies.is_empty():
		var allies_dict: Dictionary = lineup_data.allies
		await GamestateLoader._restore_lineup_positions(
			game, allies_dict, game.holder_allies, "allies"
		)
		Log.debug(
			"Restored allied lineup from lineup-only save",
			{"units_restored": lineup_data.allies.size()},
			[Log.TAG_DEBUG, "gamestate", "lineup_only"]
		)

	if lineup_data.has("enemies") and not lineup_data.enemies.is_empty():
		var enemies_dict: Dictionary = lineup_data.enemies
		await GamestateLoader._restore_lineup_positions(
			game, enemies_dict, game.holder_enemy, "enemies"
		)
		Log.debug(
			"Restored enemy lineup from lineup-only save",
			{"units_restored": lineup_data.enemies.size()},
			[Log.TAG_DEBUG, "gamestate", "lineup_only"]
		)

	Log.info(
		"Lineup-only data restoration completed",
		{
			"allies_loaded": lineup_data.get("allies", {}).size(),
			"enemies_loaded": lineup_data.get("enemies", {}).size(),
			"success": restoration_success
		},
		[Log.TAG_DEBUG, "gamestate", "lineup_only"]
	)

	return restoration_success


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

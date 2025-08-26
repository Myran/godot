class_name SaveGamestateToFileAction extends DebugAction

var _filename: String


func _init(filename: String = "") -> void:
	_filename = filename
	super("system.debug.save_gamestate_to_file", _execute_save_gamestate_to_file)
	set_category("System")
	set_group("Debug")
	set_description("Save current gamestate directly to a specific file")


func _execute_save_gamestate_to_file() -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	# Get filename from parameter or metadata
	var actual_filename: String = _filename
	if actual_filename.is_empty():
		var metadata: Dictionary = DebugConfigReader.get_metadata()
		actual_filename = metadata.get("save_filename", "test_save.json")

	Log.info(
		"Saving gamestate directly to file",
		{"filename": actual_filename},
		[Log.TAG_DEBUG, "gamestate", "save"]
	)

	# Use existing proven systems to extract state
	var game_state: Dictionary = StateExtractor.extract_game_state()
	var rng_state: String = rng.seeded_rng.save_state() if rng.seeded_rng else ""

	# Create capture data with metadata
	var capture_data: Dictionary = {
		"gamestate": game_state,
		"rng_state": rng_state,
		"capture_timestamp": Time.get_datetime_string_from_system(),
		"session_id": SessionManager.get_current_session_id(),
		"platform": OS.get_name(),
		"capture_id": _generate_capture_id(),
		"format_version": "1.0"
	}

	# Save directly to file using centralized path management
	var file_path: String = DebugConfigReader.get_saved_state_path(actual_filename)

	# Ensure directory exists
	var saved_states_dir: String = DebugConfigReader.get_saved_states_dir()
	if not DirAccess.dir_exists_absolute(saved_states_dir):
		DirAccess.make_dir_absolute(saved_states_dir)

	# Write to file
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return DebugActionResult.new_failure("Cannot create save file: " + actual_filename)

	var json_text: String = JSON.stringify(capture_data, "\t")
	file.store_string(json_text)
	file.close()

	var duration: int = Time.get_ticks_msec() - start_time

	Log.info(
		"Gamestate saved successfully to file",
		{
			"filename": actual_filename,
			"file_path": file_path,
			"capture_id": capture_data.capture_id,
			"duration_ms": duration,
			"file_size": json_text.length()
		},
		[Log.TAG_DEBUG, "gamestate", "save"]
	)

	return DebugActionResult.new_success(
		{
			"filename": actual_filename,
			"file_path": file_path,
			"capture_id": capture_data.capture_id,
			"file_size": json_text.length()
		},
		duration
	)


func _generate_capture_id() -> String:
	return (
		"capture_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000).pad_zeros(3)
	)

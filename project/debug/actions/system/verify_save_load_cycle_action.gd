class_name VerifySaveLoadCycleAction extends DebugAction

var _verification_results: Dictionary = {}


func _init() -> void:
	super("system.validation.verify_save_load_cycle", _verify_save_load_cycle)
	set_category("System")
	set_group("Validation")
	set_description("Verify that save/load/save cycle produces identical checksums")


func _verify_save_load_cycle() -> DebugAction.Result:
	"""Verify that save → load → save produces identical state checksums"""
	Log.info(
		"Starting save/load cycle validation",
		{},
		["debug", "validation", "gamestate", "cycle"]
	)

	# Get filenames from metadata
	var metadata: Dictionary = DebugConfigReader.get_metadata()
	var first_save_file: String = metadata.get("first_save_file", "cycle_test_first.json")
	var second_save_file: String = metadata.get("second_save_file", "cycle_test_second.json")
	
	# Construct full paths
	var saved_states_dir: String = "user://debug/saved_states/"
	var first_file_path: String = saved_states_dir + first_save_file
	var second_file_path: String = saved_states_dir + second_save_file

	# Load both save files
	var first_gamestate: Dictionary = _load_gamestate_file(first_file_path)
	var second_gamestate: Dictionary = _load_gamestate_file(second_file_path)

	if first_gamestate.is_empty():
		return DebugAction.Result.new_failure(
			"Could not load first save file: " + first_save_file,
			"FIRST_SAVE_FILE_NOT_FOUND"
		)

	if second_gamestate.is_empty():
		return DebugAction.Result.new_failure(
			"Could not load second save file: " + second_save_file,
			"SECOND_SAVE_FILE_NOT_FOUND"
		)

	# Calculate checksums for both files
	var first_checksum: String = _calculate_gamestate_checksum(first_gamestate)
	var second_checksum: String = _calculate_gamestate_checksum(second_gamestate)
	var checksums_match: bool = first_checksum == second_checksum

	# Compare timestamps to ensure second save is after first
	var first_timestamp: String = first_gamestate.get("capture_timestamp", "")
	var second_timestamp: String = second_gamestate.get("capture_timestamp", "")
	var timestamps_ordered: bool = second_timestamp > first_timestamp

	# Compile verification results
	_verification_results = {
		"validation_approach": "save_load_cycle_checksum_comparison",
		"first_save_loaded": not first_gamestate.is_empty(),
		"second_save_loaded": not second_gamestate.is_empty(),
		"first_file": first_save_file,
		"second_file": second_save_file,
		"first_checksum": first_checksum,
		"second_checksum": second_checksum,
		"checksums_match": checksums_match,
		"first_timestamp": first_timestamp,
		"second_timestamp": second_timestamp,
		"timestamps_ordered": timestamps_ordered,
		"overall_success": false
	}

	# Overall success requires checksums to match and proper timestamp ordering
	_verification_results.overall_success = (
		_verification_results.first_save_loaded
		and _verification_results.second_save_loaded
		and _verification_results.checksums_match
		and _verification_results.timestamps_ordered
	)

	# Log results
	var success_indicator: String = "✅" if _verification_results.overall_success else "❌"
	Log.info(
		"Save/load cycle validation completed " + success_indicator,
		_verification_results,
		["debug", "validation", "gamestate", "cycle"]
	)

	# Emit test completion signal
	if _verification_results.overall_success:
		Log.info(
			"DEBUG_TEST_SUCCESS",
			{
				"test_id": "save_load_cycle_test",
				"action": "Save/Load Cycle Validation",
				"category": "System",
				"group": "Validation",
				"duration_ms": 0
			},
			["debug", "test", "success"]
		)

		return DebugAction.Result.new_success(
			_verification_results, 0, "save_load_cycle_validated"
		)
	else:
		Log.error(
			"DEBUG_TEST_FAILURE",
			{
				"test_id": "save_load_cycle_test", 
				"action": "Save/Load Cycle Validation",
				"category": "System",
				"group": "Validation",
				"error": _get_failure_summary(),
				"details": _verification_results
			},
			["debug", "test", "failure"]
		)

		return DebugAction.Result.new_failure(
			_get_failure_summary(),
			"SAVE_LOAD_CYCLE_VALIDATION_FAILED",
			DebugAction.Result.ErrorCategory.VALIDATION
		)


func _load_gamestate_file(file_path: String) -> Dictionary:
	"""Load and parse a gamestate file"""
	Log.debug(
		"Loading gamestate file for cycle validation",
		{"file_path": file_path},
		["debug", "validation", "gamestate"]
	)
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		Log.error(
			"Cannot open gamestate file for cycle validation",
			{"file_path": file_path},
			["debug", "validation", "gamestate", "error"]
		)
		return {}
	
	var json_text: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)
	if parse_result != OK:
		Log.error(
			"Failed to parse gamestate JSON for cycle validation",
			{"file_path": file_path, "error": parse_result},
			["debug", "validation", "gamestate", "error"]
		)
		return {}
	
	var gamestate_data: Dictionary = json.data as Dictionary
	
	Log.debug(
		"Gamestate file loaded successfully for cycle validation",
		{
			"file": file_path.get_file(),
			"has_gamestate": gamestate_data.has("gamestate"),
			"has_rng_state": gamestate_data.has("rng_state"),
			"has_timestamp": gamestate_data.has("capture_timestamp")
		},
		["debug", "validation", "gamestate"]
	)
	
	return gamestate_data


func _calculate_gamestate_checksum(gamestate_data: Dictionary) -> String:
	"""Calculate checksum of gamestate data (excluding timestamps and metadata)"""
	# Extract only the core gamestate for comparison
	var gamestate: Dictionary = gamestate_data.get("gamestate", {})
	
	var clean_gamestate: Dictionary = {
		"board": gamestate.get("board", {}),
		"lineup": gamestate.get("lineup", {})
		# Exclude metadata, timestamps, session_id, etc.
	}
	
	# Convert to deterministic JSON string
	var json_string: String = JSON.stringify(clean_gamestate)
	
	# Calculate SHA256 hash
	var checksum: String = json_string.sha256_text()
	
	Log.debug(
		"Gamestate checksum calculated for cycle validation",
		{
			"checksum": checksum,
			"board_items": clean_gamestate.get("board", {}).get("draft_area", []).size(),
			"lineup_state": clean_gamestate.get("lineup", {}).get("current_game_state", "unknown"),
			"json_length": json_string.length()
		},
		["debug", "validation", "gamestate"]
	)
	
	return checksum


func _get_failure_summary() -> String:
	"""Generate failure summary for debugging"""
	var failures: Array[String] = []

	if not _verification_results.first_save_loaded:
		failures.append("First save file not loaded")
	if not _verification_results.second_save_loaded:
		failures.append("Second save file not loaded")
	if not _verification_results.checksums_match:
		failures.append("Checksums do not match - save/load cycle failed")
	if not _verification_results.timestamps_ordered:
		failures.append("Timestamps not properly ordered")

	return ", ".join(failures) if not failures.is_empty() else "Unknown failure"
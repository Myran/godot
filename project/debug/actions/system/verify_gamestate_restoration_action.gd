class_name VerifyGamestateRestorationAction extends DebugAction

var _verification_results: Dictionary = {}


func _init() -> void:
	super("system.validation.verify_gamestate_restoration", _verify_gamestate_restoration)
	set_category("System")
	set_group("Validation")
	set_description("Verify that gamestate restoration completed successfully")


func _verify_gamestate_restoration() -> DebugAction.Result:
	"""Verify gamestate restoration using save-load-save-compare approach"""
	Log.info(
		"Starting gamestate restoration verification using save-load-save-compare approach", 
		{}, ["debug", "validation", "gamestate"]
	)

	# Step 1: Load the original saved gamestate file for comparison
	var original_gamestate: Dictionary = _load_original_gamestate()
	if original_gamestate.is_empty():
		return DebugAction.Result.new_failure(
			"Could not load original gamestate file for comparison",
			"ORIGINAL_GAMESTATE_NOT_FOUND"
		)

	# Step 2: Save current state after restoration
	var current_gamestate: Dictionary = _extract_current_gamestate()
	
	# Step 3: Compare gamestates using checksums
	var original_checksum: String = _calculate_gamestate_checksum(original_gamestate)
	var current_checksum: String = _calculate_gamestate_checksum(current_gamestate)
	var checksums_match: bool = original_checksum == current_checksum

	# Compile verification results
	_verification_results = {
		"comparison_approach": "checksum_comparison",
		"original_gamestate_loaded": not original_gamestate.is_empty(),
		"current_gamestate_extracted": not current_gamestate.is_empty(),
		"original_checksum": original_checksum,
		"current_checksum": current_checksum,
		"checksums_match": checksums_match,
		"overall_success": false
	}

	# Overall success determination - checksums must match exactly
	_verification_results.overall_success = (
		_verification_results.original_gamestate_loaded
		and _verification_results.current_gamestate_extracted
		and _verification_results.checksums_match
	)

	# Log results
	var success_indicator: String = "✅" if _verification_results.overall_success else "❌"
	Log.info(
		"Gamestate restoration verification completed " + success_indicator,
		_verification_results,
		["debug", "validation", "gamestate"]
	)

	# Emit test completion signal for automated testing
	if _verification_results.overall_success:
		Log.info(
			"DEBUG_TEST_SUCCESS",
			{
				"test_id": "gamestate_save_load_test",
				"action": "Gamestate Save/Load System Validation",
				"category": "System",
				"group": "Validation",
				"duration_ms": 0  # Will be calculated by test framework
			},
			["debug", "test", "success"]
		)

		return DebugAction.Result.new_success(
			_verification_results, 0, "gamestate_restoration_verified"
		)
	else:
		Log.error(
			"DEBUG_TEST_FAILURE",
			{
				"test_id": "gamestate_save_load_test",
				"action": "Gamestate Save/Load System Validation",
				"category": "System",
				"group": "Validation",
				"error": _get_failure_summary(),
				"details": _verification_results
			},
			["debug", "test", "failure"]
		)

		return DebugAction.Result.new_failure(
			_get_failure_summary(),
			"GAMESTATE_RESTORATION_FAILED",
			DebugAction.Result.ErrorCategory.VALIDATION
		)


func _load_original_gamestate() -> Dictionary:
	"""Load the original gamestate file that was used for restoration"""
	# Get the gamestate file name from test metadata
	var metadata: Dictionary = DebugConfigReader.get_metadata()
	var gamestate_filename: String = metadata.get("gamestate_file", "test-save-load-validation.json")
	
	# Construct full path to saved state file
	var saved_states_dir: String = "user://debug/saved_states/"
	var gamestate_file_path: String = saved_states_dir + gamestate_filename
	
	Log.debug(
		"Loading original gamestate file for comparison",
		{"file_path": gamestate_file_path, "filename": gamestate_filename},
		["debug", "validation", "gamestate"]
	)
	
	# Read and parse JSON file
	var file: FileAccess = FileAccess.open(gamestate_file_path, FileAccess.READ)
	if not file:
		Log.error(
			"Cannot open original gamestate file",
			{"file_path": gamestate_file_path},
			["debug", "validation", "gamestate", "error"]
		)
		return {}
	
	var json_text: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)
	if parse_result != OK:
		Log.error(
			"Failed to parse original gamestate JSON",
			{"file_path": gamestate_file_path, "error": parse_result},
			["debug", "validation", "gamestate", "error"]
		)
		return {}
	
	var gamestate_data: Dictionary = json.data as Dictionary
	var original_gamestate: Dictionary = gamestate_data.get("gamestate", {})
	
	Log.info(
		"Original gamestate loaded successfully",
		{
			"board_items": original_gamestate.get("board", {}).get("draft_area", []).size(),
			"game_state": original_gamestate.get("lineup", {}).get("current_game_state", "unknown"),
			"source_file": gamestate_filename
		},
		["debug", "validation", "gamestate"]
	)
	
	return original_gamestate


func _extract_current_gamestate() -> Dictionary:
	"""Extract current game state for analysis"""
	var current_state: Dictionary = StateExtractor.extract_game_state()

	Log.debug(
		"Current gamestate extracted for verification",
		{
			"board_items": current_state.get("board", {}).get("draft_area", []).size(),
			"game_state": current_state.get("lineup", {}).get("current_game_state", "unknown"),
			"ui_state": current_state.get("lineup", {}).get("ui_state", "unknown")
		},
		["debug", "validation", "gamestate"]
	)

	return current_state


func _calculate_gamestate_checksum(gamestate: Dictionary) -> String:
	"""Calculate checksum of gamestate data (excluding timestamps and metadata)"""
	# Create a clean copy with only the essential game state data
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
		"Gamestate checksum calculated",
		{
			"checksum": checksum,
			"board_items": clean_gamestate.get("board", {}).get("draft_area", []).size(),
			"lineup_state": clean_gamestate.get("lineup", {}).get("current_game_state", "unknown"),
			"json_length": json_string.length()
		},
		["debug", "validation", "gamestate"]
	)
	
	return checksum




func _get_game_instance() -> Game:
	"""Get the current Game instance"""
	var main_loop: SceneTree = Engine.get_main_loop()
	if not main_loop:
		return null
	var current_scene: Node = main_loop.current_scene
	if current_scene and current_scene.has_node("Game"):
		return current_scene.get_node("Game") as Game
	return null


func _get_failure_summary() -> String:
	"""Generate failure summary for debugging"""
	var failures: Array[String] = []

	if not _verification_results.original_gamestate_loaded:
		failures.append("Original gamestate file not loaded")
	if not _verification_results.current_gamestate_extracted:
		failures.append("Current gamestate not extracted")
	if not _verification_results.checksums_match:
		failures.append("Checksums do not match - state restoration failed")

	return ", ".join(failures) if not failures.is_empty() else "Unknown failure"

class_name SaveDebugStateAction extends DebugAction


func _init() -> void:
	super("system.debug.save_gamestate", _execute_save_gamestate)
	set_category("System")
	set_group("Debug")
	set_description("Capture current gamestate for later loading and replay generation")
	set_use_auto_success_logging(false)  # Handles its own success logging for batch execution


func _execute_save_gamestate() -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	Log.info("Capturing debug gamestate...", {}, [Log.TAG_DEBUG])

	# Use existing proven systems with error handling
	Log.info("Starting StateExtractor.extract_game_state()...", {}, [Log.TAG_DEBUG])
	var game_state: Dictionary = StateExtractor.extract_game_state()
	Log.info(
		"StateExtractor.extract_game_state() completed",
		{"state_size": game_state.size()},
		[Log.TAG_DEBUG]
	)

	# Check if extraction failed
	if game_state.is_empty():
		Log.error("StateExtractor returned empty state", {}, [Log.TAG_DEBUG])
		return DebugActionResult.new_failure("StateExtractor returned empty state")

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

	# Log with special marker for command-line extraction
	Log.info(
		"DEBUG_GAMESTATE_CAPTURE", capture_data, ["debug", "gamestate", "capture", "extractable"]
	)

	var duration: int = Time.get_ticks_msec() - start_time

	# CRITICAL FIX: Log success BEFORE returning DebugActionResult
	# because batch execution may terminate app before normal completion callbacks fire
	# (same pattern as system.debug.replay_complete)
	_log_test_success("system.debug.save_gamestate", "System", "Debug", duration, {})

	Log.info(
		"Debug gamestate captured successfully",
		{
			"capture_id": capture_data.capture_id,
			"duration_ms": duration,
			"state_size_estimate": JSON.stringify(game_state).length()
		},
		[Log.TAG_DEBUG]
	)

	return DebugActionResult.new_success(
		{
			"capture_id": capture_data.capture_id,
			"instructions": "Use 'just capture-gamestate NAME' to extract this state"
		}
	)


func _generate_capture_id() -> String:
	return (
		"capture_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000).pad_zeros(3)
	)

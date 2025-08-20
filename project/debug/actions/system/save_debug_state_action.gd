class_name SaveDebugStateAction extends DebugAction


func _init() -> void:
	super("system.debug.save_gamestate", _execute_save_gamestate)
	set_category("System")
	set_group("Debug")
	set_description("Capture current gamestate for later loading and replay generation")


func _execute_save_gamestate() -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()

	Log.info("Capturing debug gamestate...", {}, [Log.TAG_DEBUG])

	# Use existing proven systems
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

	# Log with special marker for command-line extraction
	Log.info(
		"DEBUG_GAMESTATE_CAPTURE", capture_data, ["debug", "gamestate", "capture", "extractable"]
	)

	var duration: int = Time.get_ticks_msec() - start_time

	Log.info(
		"Debug gamestate captured successfully",
		{
			"capture_id": capture_data.capture_id,
			"duration_ms": duration,
			"state_size_estimate": JSON.stringify(game_state).length()
		},
		[Log.TAG_DEBUG]
	)

	return DebugAction.Result.new_success(
		{
			"capture_id": capture_data.capture_id,
			"instructions": "Use 'just capture-gamestate NAME' to extract this state"
		}
	)


func _generate_capture_id() -> String:
	return (
		"capture_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000).pad_zeros(3)
	)

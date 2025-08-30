class_name SaveAlliedLineupAction extends DebugAction


func _init() -> void:
	super("system.debug.save_allied_lineup", _execute_save_allied_lineup)
	set_category("System")
	set_group("Lineup")
	set_description("Save current allied lineup for testing and battle scenario setup")


func _execute_save_allied_lineup() -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	Log.info("Capturing allied lineup for testing...", {}, [Log.TAG_DEBUG, "lineup", "allied"])

	# Use new lineup-specific extraction method
	var lineup_data: Dictionary = StateExtractor.extract_allied_lineup_only()
	var rng_state: String = rng.seeded_rng.save_state() if rng.seeded_rng else ""

	# Create capture data with metadata following established pattern
	var capture_data: Dictionary = {
		"lineup_data": lineup_data,
		"rng_state": rng_state,
		"capture_timestamp": Time.get_datetime_string_from_system(),
		"session_id": SessionManager.get_current_session_id(),
		"platform": OS.get_name(),
		"capture_id": _generate_capture_id(),
		"format_version": "1.0",
		"lineup_type": "allied",
		"debug_only": true
	}

	# Log with special marker for command-line extraction (follows DEBUG_GAMESTATE_CAPTURE pattern)
	Log.info(
		"DEBUG_LINEUP_ALLIED_CAPTURE", capture_data, ["debug", "lineup", "allied", "extractable"]
	)

	var duration: int = Time.get_ticks_msec() - start_time

	Log.info(
		"Allied lineup captured successfully",
		{
			"capture_id": capture_data.capture_id,
			"duration_ms": duration,
			"allied_units": lineup_data.get("allies", {}).size(),
			"lineup_type": "allied"
		},
		[Log.TAG_DEBUG, "lineup", "allied"]
	)

	return DebugActionResult.new_success(
		{
			"capture_id": capture_data.capture_id,
			"lineup_type": "allied",
			"units_captured": lineup_data.get("allies", {}).size(),
			"instructions": "Use 'just capture-lineup-allied NAME' to extract this lineup"
		}
	)


func _generate_capture_id() -> String:
	return (
		"lineup_allied_"
		+ str(Time.get_unix_time_from_system())
		+ "_"
		+ str(randi() % 1000).pad_zeros(3)
	)

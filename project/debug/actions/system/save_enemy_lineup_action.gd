class_name SaveEnemyLineupAction extends DebugAction


func _init() -> void:
	super("system.debug.save_enemy_lineup", _execute_save_enemy_lineup)
	set_category("System")
	set_group("Lineup")
	set_description("Save current enemy lineup for testing and battle scenario setup")


func _execute_save_enemy_lineup() -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	Log.info("Capturing enemy lineup for testing...", {}, [Log.TAG_DEBUG, "lineup", "enemy"])

	# Use new lineup-specific extraction method
	var lineup_data: Dictionary = StateExtractor.extract_enemy_lineup_only()
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
		"lineup_type": "enemy",
		"debug_only": true
	}

	# Log with special marker for command-line extraction (follows DEBUG_GAMESTATE_CAPTURE pattern)
	Log.info(
		"DEBUG_LINEUP_ENEMY_CAPTURE", capture_data, ["debug", "lineup", "enemy", "extractable"]
	)

	var duration: int = Time.get_ticks_msec() - start_time

	Log.info(
		"Enemy lineup captured successfully",
		{
			"capture_id": capture_data.capture_id,
			"duration_ms": duration,
			"enemy_units": lineup_data.get("enemies", {}).size(),
			"lineup_type": "enemy"
		},
		[Log.TAG_DEBUG, "lineup", "enemy"]
	)

	return DebugActionResult.new_success(
		{
			"capture_id": capture_data.capture_id,
			"lineup_type": "enemy",
			"units_captured": lineup_data.get("enemies", {}).size(),
			"instructions": "Use 'just capture-lineup-enemy NAME' to extract this lineup"
		}
	)


func _generate_capture_id() -> String:
	return (
		"lineup_enemy_"
		+ str(Time.get_unix_time_from_system())
		+ "_"
		+ str(randi() % 1000).pad_zeros(3)
	)

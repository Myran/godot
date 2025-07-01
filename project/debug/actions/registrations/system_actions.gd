# project/debug/actions/registrations/system_actions.gd
# System-level debug actions for infrastructure and platform utilities

class_name SystemActions

# Using class_name resolution instead of preload as requested


static func register_all(registry: DebugActionRegistry) -> void:
	_register_memory_actions(registry)
	_register_debug_system_actions(registry)
	_register_connectivity_actions(registry)
	_register_checksum_actions(registry)
	_register_recording_actions(registry)
	_register_test_actions(registry)

	Log.info("System debug actions registered", {}, ["debug", "system"])


static func _register_memory_actions(registry: DebugActionRegistry) -> void:
	# System memory utilities
	registry.register_action(
		(
			DebugAction
			. create("system.memory.force_warning", _force_low_memory)
			. set_category("System")
			. set_group("Memory")
			. set_description("Simulates low memory condition for testing memory management")
		)
	)


static func _register_debug_system_actions(registry: DebugActionRegistry) -> void:
	# Registry introspection utilities
	registry.register_action(
		(
			DebugAction
			. create(
				"system.debug.registry_stats", func() -> bool: return _show_registry_stats(registry)
			)
			. set_category("System")
			. set_group("Debug")
			. set_description("Display debug action registry statistics")
		)
	)

	# Registry introspection utilities
	registry.register_action(
		(
			DebugAction
			. create("system.debug.quit_application", func() -> bool: return _quit_application())
			. set_category("System")
			. set_group("Debug")
			. set_description("Quit Application")
		)
	)


#static func _quit() -> void:
#DebugManager.action(DebugManager.DebugEventType.EVENT_QUIT)


static func _register_connectivity_actions(registry: DebugActionRegistry) -> void:
	# RTDB Status check - always available
	registry.register_action(
		(
			DebugAction
			. create("system.network.rtdb_status", _rtdb_status_check)
			. set_category("RTDB")
			. set_group("Utilities")
			. set_description("Check RTDB availability and connection status")
		)
	)


static func _register_checksum_actions(registry: DebugActionRegistry) -> void:
	# Checksum validation for state testing
	registry.register_action(
		(
			DebugAction
			. create("system.checksum.validate", _validate_checksum)
			. set_category("System")
			. set_group("Validation")
			. set_description("Validate captured state against expected checksum")
		)
	)


# System action implementations
static func _force_low_memory() -> bool:
	# Simulate low memory condition
	Log.warning("Simulating low memory condition for testing", {}, ["debug", "system", "memory"])

	if OS.has_method("low_processor_usage_mode"):
		var old_mode: bool = OS.low_processor_usage_mode
		OS.low_processor_usage_mode = true
		OS.low_processor_usage_mode = old_mode

	Log.info("Low memory simulation completed", {}, ["debug", "system", "memory"])
	return true


static func _show_registry_stats(registry: DebugActionRegistry) -> bool:
	# Display debug action registry statistics
	var stats: Dictionary = {
		"total_actions": registry.get_all_actions().size(),
		"total_categories": registry.get_categories().size(),
		"categories": {}
	}

	for category: String in registry.get_categories():
		var category_stats: Dictionary = {
			"groups": registry.get_groups_for_category(category).size(),
			"ungrouped_actions": registry.get_ungrouped_actions(category).size(),
			"total_actions": 0
		}

		for group: String in registry.get_groups_for_category(category):
			category_stats.total_actions += registry.get_actions_for_group(category, group).size()
		category_stats.total_actions += category_stats.ungrouped_actions

		stats.categories[category] = category_stats

	Log.info("Debug Action Registry Statistics", stats, ["debug", "registry", "stats"])
	return true


static func _quit_application() -> bool:
	# Quit the application
	DebugManager.action(DebugManager.DebugEventType.EVENT_QUIT)
	return true


static func _rtdb_status_check() -> bool:
	# Check RTDB status and availability
	var status: Dictionary = {
		"firebase_database_available": ClassDB.class_exists("FirebaseDatabase"),
		"firebase_auth_available": ClassDB.class_exists("FirebaseAuth"),
		"platform": OS.get_name(),
		"timestamp": Time.get_unix_time_from_system()
	}

	Log.info("RTDB Status Check", status, ["debug", "rtdb", "status"])
	return true


static func _validate_checksum() -> DebugAction.Result:
	var process_id: int = OS.get_process_id()
	var current_test_id: String = DebugAction.get_current_test_id()

	Log.info(
		"=== CHECKSUM VALIDATION ENTRY ===",
		{
			"pid": process_id,
			"test_id": current_test_id,
			"timestamp": Time.get_datetime_string_from_system(),
			"phase": "validation"
		},
		["debug", "checksum", "validation", "pid", "phase"]
	)

	# Use variables to satisfy Godot compiler warnings
	assert(process_id > 0, "Process ID should be positive")
	assert(current_test_id != "", "Test ID should not be empty")

	# Load config to get expected checksum
	var config_path: String = "user://debug_startup_actions.json"

	if not FileAccess.file_exists(config_path):
		Log.error(
			"Config file not found for checksum validation",
			{"config_path": config_path, "pid": process_id, "test_id": current_test_id},
			["debug", "checksum", "validation", "error", "pid"]
		)
		return DebugAction.Result.new_failure(
			"No config file found for checksum validation", "CONFIG_NOT_FOUND"
		)

	var file: FileAccess = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		Log.error(
			"Could not open config file for reading",
			{
				"config_path": config_path,
				"pid": process_id,
				"test_id": current_test_id,
				"error": FileAccess.get_open_error()
			},
			["debug", "checksum", "validation", "error", "pid"]
		)
		return DebugAction.Result.new_failure("Could not read config file", "CONFIG_READ_ERROR")

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var result: Error = json.parse(json_text)
	if result != OK:
		Log.error(
			"Invalid JSON in config file",
			{
				"config_path": config_path,
				"parse_error": result,
				"error_line": json.error_line,
				"error_string": json.error_string,
				"pid": process_id,
				"test_id": current_test_id
			},
			["debug", "checksum", "validation", "error", "pid"]
		)
		return DebugAction.Result.new_failure("Invalid JSON in config file", "JSON_PARSE_ERROR")

	var config: Dictionary = json.data
	var checksum_config: Dictionary = config.get("checksum_config", {})
	var expected: String = checksum_config.get("expected_checksum", "")
	var state_type: String = checksum_config.get("state_type", "unknown")

	# Get current checksum from capture action
	var current: String = CaptureActionBase.get_last_checksum(state_type)

	if current.is_empty():
		Log.error(
			"No current checksum available for validation",
			{"state_type": state_type, "pid": process_id, "test_id": current_test_id},
			["debug", "checksum", "validation", "error", "pid"]
		)
		return DebugAction.Result.new_failure(
			"No current checksum available - capture action may not have run", "NO_CURRENT_CHECKSUM"
		)

	if expected.is_empty():
		# First run - signal for auto-save
		Log.info(
			"CHECKSUM_FIRST_RUN",
			{
				"checksum": current,
				"state_type": state_type,
				"pid": process_id,
				"test_id": current_test_id
			},
			["checksum", "first_run", state_type, "pid"]
		)
		return DebugAction.Result.new_success(
			{
				"action": "first_run_saved",
				"checksum": current,
				"state_type": state_type,
				"pid": process_id
			},
			0,
			"checksum_first_run"
		)

	# Validate against expected checksum
	if current == expected:
		Log.info(
			"CHECKSUM_VALID",
			{
				"checksum": current,
				"state_type": state_type,
				"pid": process_id,
				"test_id": current_test_id
			},
			["checksum", "valid", state_type, "pid"]
		)
		return DebugAction.Result.new_success(
			{
				"action": "validated",
				"checksum": current,
				"state_type": state_type,
				"pid": process_id
			},
			0,
			"checksum_validated"
		)
	else:
		Log.error(
			"CHECKSUM_MISMATCH",
			{
				"expected": expected,
				"actual": current,
				"state_type": state_type,
				"pid": process_id,
				"test_id": current_test_id
			},
			["checksum", "mismatch", state_type, "pid"]
		)
		return DebugAction.Result.new_failure("Checksum validation failed", "CHECKSUM_MISMATCH")


static func _register_recording_actions(registry: DebugActionRegistry) -> void:
	# Recording system actions for action recording and replay
	Log.info("Registering recording actions", {}, ["debug", "recording", "registration"])
	registry.register_action(
		(
			DebugAction
			. create("system.recording.start", _start_recording)
			. set_category("System")
			. set_group("Recording")
			. set_description("Start recording player actions for replay")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("system.recording.stop", _stop_recording)
			. set_category("System")
			. set_group("Recording")
			. set_description("Stop recording and show recording stats")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("system.recording.save", _save_recording)
			. set_category("System")
			. set_group("Recording")
			. set_description("Save current recording to file")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("system.recording.capture_state", _capture_recording_state)
			. set_category("System")
			. set_group("Recording")
			. set_description("Capture recording system state for validation")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("system.recording.stats", _show_recording_stats)
			. set_category("System")
			. set_group("Recording")
			. set_description("Display current recording statistics")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("system.recording.replay", _replay_recording)
			. set_category("System")
			. set_group("Recording")
			. set_description("Replay a recording file with automatic validation")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("system.recording.reset_and_replay", _reset_and_replay_recording)
			. set_category("System")
			. set_group("Recording")
			. set_description("Reset game state and replay a recording file")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("system.recording.list_recordings", _list_recordings)
			. set_category("System")
			. set_group("Recording")
			. set_description("List all available recording files")
		)
	)


# Recording action implementations
static func _start_recording() -> bool:
	if not ActionRecorder:
		Log.error("ActionRecorder singleton not available", {}, ["debug", "recording", "error"])
		return false

	var success: bool = ActionRecorder.start_recording()
	Log.info("Recording start requested", {"success": success}, ["debug", "recording", "start"])
	return success


static func _stop_recording() -> bool:
	if not ActionRecorder:
		Log.error("ActionRecorder singleton not available", {}, ["debug", "recording", "error"])
		return false

	var success: bool = ActionRecorder.stop_recording()
	if success:
		var stats: Dictionary = ActionRecorder.get_recording_stats()
		Log.info("Recording stopped", stats, ["debug", "recording", "stop"])
	return success


static func _save_recording() -> bool:
	if not ActionRecorder:
		Log.error("ActionRecorder singleton not available", {}, ["debug", "recording", "error"])
		return false

	var filepath: String = ActionRecorder.save_recording()
	var success: bool = not filepath.is_empty()

	if success:
		Log.info("Recording saved", {"filepath": filepath}, ["debug", "recording", "save"])
	else:
		Log.error("Failed to save recording", {}, ["debug", "recording", "save", "error"])

	return success


static func _capture_recording_state() -> DebugAction.Result:
	# Create recording capture action using class_name
	var capture_action: RecordingCaptureAction = RecordingCaptureAction.new()
	return capture_action.execute()


static func _show_recording_stats() -> bool:
	if not ActionRecorder:
		Log.error("ActionRecorder singleton not available", {}, ["debug", "recording", "error"])
		return false

	var stats: Dictionary = ActionRecorder.get_recording_stats()
	Log.info("Recording System Statistics", stats, ["debug", "recording", "stats"])
	return true


static func _replay_recording() -> bool:
	if not ActionRecorder:
		Log.error("ActionRecorder singleton not available", {}, ["debug", "recording", "error"])
		return false

	# Get list of available recordings
	var recordings: Array[String] = ActionRecorder.list_recordings()
	if recordings.is_empty():
		Log.warning("No recordings available for replay", {}, ["debug", "recording", "replay"])
		return false

	# For now, replay the most recent recording
	# TODO: Add fzf selector integration
	var latest_recording: String = recordings[recordings.size() - 1]  # Last (most recent) recording
	var filepath: String = ActionRecorder.RECORDINGS_DIR + latest_recording

	var log_message: String = "Replaying recording"
	var log_metadata: Dictionary = {"file": latest_recording, "filepath": filepath}
	var log_tags: Array[String] = ["debug", "recording", "replay"]
	Log.info(log_message, log_metadata, log_tags)

	# Get expected checksum from config if available
	var config: Dictionary = _get_replay_config()

	var success: bool = ActionRecorder.replay_recording(filepath, config)
	return success


static func _reset_and_replay_recording() -> bool:
	if not ActionRecorder:
		Log.error("ActionRecorder singleton not available", {}, ["debug", "recording", "error"])
		return false

	# Get list of available recordings
	var recordings: Array[String] = ActionRecorder.list_recordings()
	if recordings.is_empty():
		Log.warning("No recordings available for replay", {}, ["debug", "recording", "replay"])
		return false

	# For now, replay the most recent recording with game reset
	var latest_recording: String = recordings[recordings.size() - 1]
	var filepath: String = ActionRecorder.RECORDINGS_DIR + latest_recording

	var log_message: String = "Resetting and replaying recording"
	var log_metadata: Dictionary = {"file": latest_recording, "filepath": filepath}
	var log_tags: Array[String] = ["debug", "recording", "replay"]
	Log.info(log_message, log_metadata, log_tags)

	# Force game reset and get config
	var config: Dictionary = _get_replay_config()
	config["reset_game"] = true

	var success: bool = ActionRecorder.replay_recording(filepath, config)
	return success


static func _list_recordings() -> bool:
	if not ActionRecorder:
		Log.error("ActionRecorder singleton not available", {}, ["debug", "recording", "error"])
		return false

	var recordings: Array[String] = ActionRecorder.list_recordings()

	Log.info(
		"Available Recordings",
		{"count": recordings.size(), "recordings": recordings},
		["debug", "recording", "list"]
	)

	return true


static func _get_replay_config() -> Dictionary:
	# Try to get replay configuration from current test config
	var config_path: String = "user://debug_startup_actions.json"
	var config: Dictionary = {}

	if FileAccess.file_exists(config_path):
		var file: FileAccess = FileAccess.open(config_path, FileAccess.READ)
		if file:
			var json_text: String = file.get_as_text()
			file.close()

			var json: JSON = JSON.new()
			if json.parse(json_text) == OK and json.data is Dictionary:
				var data: Dictionary = json.data
				if data.has("checksum_config"):
					var checksum_config: Dictionary = data.checksum_config
					config["expected_checksum"] = checksum_config.get("expected_checksum", "")
					config["state_type"] = checksum_config.get("state_type", "")

	return config


static func _register_test_actions(registry: DebugActionRegistry) -> void:
	# Test actions for validating Phase 1 implementation
	Log.info("Registering test actions", {}, ["debug", "test", "registration"])

	# Register the event categorization test action using class_name
	var test_action: TestEventCategorizationAction = TestEventCategorizationAction.new()
	registry.register_action(test_action)

	# Register simple reroll test action for var2str testing
	registry.register_action(
		(
			DebugAction
			. create("system.test.generate_simple_player_events", _generate_simple_player_events)
			. set_category("System")
			. set_group("Test")
			. set_description(
				"Generate simple PLAYER events (RerollDraftEvent) for var2str testing"
			)
		)
	)

	# Register Action Recording system test using class_name
	var action_recording_test: TestActionRecordingSystem = TestActionRecordingSystem.new()
	registry.register_action(action_recording_test)

	# Register basic Action Serialization test for debugging
	var basic_action_serialization_test: TestBasicActionSerialization = (
		TestBasicActionSerialization.new()
	)
	registry.register_action(basic_action_serialization_test)

	# Register phase transition recording test
	var phase_transition_test: TestPhaseTransitionRecording = TestPhaseTransitionRecording.new()
	registry.register_action(phase_transition_test)

	# Register replay system comprehensive test using preload to avoid class resolution issues
	var replay_system_test_script: GDScript = preload("res://debug/actions/test_replay_system.gd")
	var replay_system_test: DebugAction = replay_system_test_script.new()
	registry.register_action(replay_system_test)

	# Register debug menu visibility test using class_name
	var debug_menu_visibility_test: TestDebugMenuVisibility = TestDebugMenuVisibility.new()
	registry.register_action(debug_menu_visibility_test)

	# Register simple combination events test using class_name
	var combination_events_test: TestCombinationEvents = TestCombinationEvents.new()
	registry.register_action(combination_events_test)


static func _generate_simple_player_events() -> bool:
	Log.info(
		"Generating simple PLAYER events for var2str testing", {}, ["debug", "test", "var2str"]
	)

	# Queue event generation to execute when system is ready (using SystemIdleActionEvent)
	var generate_callable: Callable = func() -> void:
		var message: String = "Executing queued player event generation"
		var metadata: Dictionary = {}
		var tags: Array[String] = ["debug", "test", "var2str", "idle"]
		Log.info(message, metadata, tags)

		# Generate RerollDraftEvent (PLAYER source)
		var reroll_event: core.RerollDraftEvent = core.RerollDraftEvent.new()
		var event_type: String = "RerollDraftEvent"
		var source: String = "PLAYER"
		Log.info(
			"Generated RerollDraftEvent",
			{"event_type": event_type, "source": source},
			["debug", "test", "event_generation"]
		)
		core.action(reroll_event)

		# Generate UpgradeEvent (PLAYER source)
		var upgrade_level: int = 2
		var upgrade_event: core.UpgradeEvent = core.UpgradeEvent.new(upgrade_level)
		var upgrade_event_type: String = "UpgradeEvent"
		var upgrade_source: String = "PLAYER"
		Log.info(
			"Generated UpgradeEvent",
			{
				"event_type": upgrade_event_type,
				"new_level": upgrade_level,
				"source": upgrade_source
			},
			["debug", "test", "event_generation"]
		)
		core.action(upgrade_event)

		var events_count: int = 2
		var completion_message: String = "Simple PLAYER events generated successfully"
		var completion_metadata: Dictionary = {"events_generated": events_count}
		var completion_tags: Array[String] = ["debug", "test", "completion"]
		Log.info(completion_message, completion_metadata, completion_tags)

	# Queue via SystemIdleActionEvent - will execute when system is ready
	core.action(core.SystemIdleActionEvent.new(generate_callable))

	Log.info(
		"Player event generation queued for when system is ready", {}, ["debug", "test", "var2str"]
	)
	return true

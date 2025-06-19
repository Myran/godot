# project/debug/actions/registrations/system_actions.gd
# System-level debug actions for infrastructure and platform utilities

class_name SystemActions


static func register_all(registry: DebugActionRegistry) -> void:
	_register_memory_actions(registry)
	_register_debug_system_actions(registry)
	_register_connectivity_actions(registry)
	_register_checksum_actions(registry)

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

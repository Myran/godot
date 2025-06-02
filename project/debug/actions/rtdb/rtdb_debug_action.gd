func _init() -> void:
	# Set category to RTDB by default, subclasses can override
	category = "RTDB"


func _ready() -> void:
	super._ready()
	# Connect to execution_completed signal for test tracking after parent setup
	if not execution_completed.is_connected(_on_execution_completed):
		execution_completed.connect(_on_execution_completed)


# Handle test tracking when action completes
func _on_execution_completed(success: bool, result: Variant) -> void:
	if DebugAction.current_test_id != "":
		if success:
			DebugAction.test_success_count += 1
			Log.info(
				"DEBUG_TEST_SUCCESS",
				{
					"test_id": DebugAction.current_test_id,
					"action": action_name,
					"category": category,
					"group": group,
					"duration_ms": 0  # Could be enhanced with timing
				},
				["debug", "test", "success"]
			)
		else:
			DebugAction.test_failure_count += 1
			Log.error(
				"DEBUG_TEST_FAILURE",
				{
					"test_id": DebugAction.current_test_id,
					"action": action_name,
					"category": category,
					"group": group,
					"error": str(result),
					"duration_ms": 0  # Could be enhanced with timing
				},
				["debug", "test", "failure"]
			)


# Enhanced execute method with test tracking
func execute() -> void:
	# Track test execution if we're in test context
	if DebugAction.current_test_id != "":
		DebugAction.test_action_count += 1

	# Call the actual implementation
	execute_rtdb_action()


# Default execute implementation - subclasses should override this
func execute_rtdb_action() -> void:
	push_error("execute_rtdb_action() not implemented in " + get_script().get_path())
	_update_status("ERROR: execute_rtdb_action() not implemented", true)
	execution_completed.emit(false, {"error": "Not implemented"})

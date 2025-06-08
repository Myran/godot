# project/debug/actions/rtdb/rtdb_set_nested_path_action.gd
class_name RTDBSetNestedPathAction
extends RTDBDebugAction


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "Set Nested Path"
	group = "Paths"
	description = "Creates/updates a nested JSON structure at a test path in RTDB."


func execute_rtdb_action() -> bool:
	_update_status("Executing " + action_name + "...")
	var nested_data: Dictionary = {
		"metadata":
		{"created_at": TimeUtils.now_ms(), "test_type": "nested_structure", "version": "2.0"},
		"data":
		{
			"user_info":
			{"name": "Test User " + str(TimeUtils.now_ms()), "level": 42, "active": true},
			"settings": {"theme": "dark", "notifications": true, "language": "en"}
		},
		"stats": {"total_tests": 456, "success_rate": 0.98, "last_updated": TimeUtils.now_ms()}
	}

	var success: bool = await execute_simple_operation(
		"set_value_async",
		RTDBTestPaths.to_variant_array(RTDBTestPaths.NESTED_DATA),
		nested_data,
		action_name
	)

	# The execution_completed signal is handled inside execute_simple_operation
	# Just return the success status for test tracking
	return success

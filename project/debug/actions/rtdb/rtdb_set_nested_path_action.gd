# project/debug/actions/rtdb/rtdb_set_nested_path_action.gd
class_name RTDBSetNestedPathAction
extends RTDBDebugAction


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "Set Nested Path"
	group = "Paths"
	description = "Creates/updates a nested JSON structure at a test path in RTDB."


# New DebugAction.Result pattern - this is the future
func _execute_action_logic(params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()

	var firebase_backend: Object = get_firebase_database()
	if not firebase_backend:
		return DebugAction.Result.new_failure(
			"Firebase database not available",
			"DATABASE_UNAVAILABLE",
			DebugAction.Result.ErrorCategory.DATABASE,
			null,
			Time.get_ticks_msec() - start_time,
			action_name
		)

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

	var nested_path: Array[Variant] = RTDBTestPaths.to_variant_array(RTDBTestPaths.NESTED_DATA)
	var operation_start: int = Time.get_ticks_msec()
	var success: bool = await execute_simple_operation(
		"set_value_async", nested_path, nested_data, action_name
	)
	var operation_duration: int = Time.get_ticks_msec() - operation_start
	var total_duration: int = Time.get_ticks_msec() - start_time

	if success:
		return DebugAction.Result.new_success(
			"Successfully set nested path data",
			total_duration,
			action_name,
			{
				"test_type": "rtdb_set_nested_path",
				"path": nested_path,
				"operation_duration_ms": operation_duration,
				"data_structure": nested_data.keys(),
				"data_size_bytes": str(nested_data).length()
			}
		)
	else:
		return DebugAction.Result.new_failure(
			"Failed to set nested path data",
			"SET_OPERATION_FAILED",
			DebugAction.Result.ErrorCategory.DATABASE,
			null,
			total_duration,
			action_name,
			{
				"test_type": "rtdb_set_nested_path",
				"path": nested_path,
				"operation_duration_ms": operation_duration,
				"attempted_data_size_bytes": str(nested_data).length()
			}
		)


# Legacy method for compatibility - delegates to new pattern
func execute_rtdb_action() -> bool:
	var result: DebugAction.Result = await _execute_action_logic({})
	return result.is_success()

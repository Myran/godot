# project/debug/actions/rtdb/rtdb_update_value_action.gd
class_name RTDBUpdateValueAction
extends RTDBDebugAction


func _init() -> void:
	super._init()
	action_name = "rtdb.database.update_value"


# New DebugAction.Result pattern - this is the future
func _execute_action_logic(_params: Dictionary = {}) -> DebugAction.Result:
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

	var path_suffix: Array[Variant] = ["update_test"]
	var test_path: Array[Variant] = create_test_path(path_suffix)
	var test_value: String = "Updated Value: " + str(Time.get_ticks_msec())

	var operation_start: int = Time.get_ticks_msec()
	var success: bool = await execute_simple_operation(
		"set_value_async", test_path, test_value, action_name
	)
	var operation_duration: int = Time.get_ticks_msec() - operation_start
	var total_duration: int = Time.get_ticks_msec() - start_time

	if success:
		return DebugAction.Result.new_success(
			"Successfully updated value",
			total_duration,
			action_name,
			{
				"test_type": "rtdb_update_value",
				"path": test_path,
				"updated_value": test_value,
				"operation_duration_ms": operation_duration
			}
		)
	else:
		return DebugAction.Result.new_failure(
			"Failed to update value",
			"UPDATE_OPERATION_FAILED",
			DebugAction.Result.ErrorCategory.DATABASE,
			null,
			total_duration,
			action_name,
			{
				"test_type": "rtdb_update_value",
				"path": test_path,
				"attempted_value": test_value,
				"operation_duration_ms": operation_duration
			}
		)


# Legacy method for compatibility - delegates to new pattern
func execute_rtdb_action() -> bool:
	var result: DebugAction.Result = await _execute_action_logic({})
	return result.is_success()

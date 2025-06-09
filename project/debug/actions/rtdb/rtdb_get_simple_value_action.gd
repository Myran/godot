# project/debug/actions/rtdb/rtdb_get_simple_value_action.gd
class_name RTDBGetSimpleValueAction
extends RTDBDebugAction


func _init() -> void:
	super._init()
	action_name = "Get Simple Value"


# New DebugAction.Result pattern - this is the future
func _execute_action_logic(params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()

	var firebase_backend: Object = get_firebase_database()
	if not firebase_backend:
		return DebugAction.Result.new_failure(
			"Firebase backend not available",
			"BACKEND_UNAVAILABLE",
			DebugAction.Result.ErrorCategory.SYSTEM,
			null,
			Time.get_ticks_msec() - start_time,
			action_name
		)

	if not firebase_backend.is_available():
		return DebugAction.Result.new_failure(
			"Firebase backend not initialized",
			"BACKEND_NOT_INITIALIZED",
			DebugAction.Result.ErrorCategory.SYSTEM,
			null,
			Time.get_ticks_msec() - start_time,
			action_name
		)

	var path: RTDBTestPaths.Path = RTDBTestPaths.create_path(RTDBTestPaths.SIMPLE_VALUE)
	var operation_start: int = Time.get_ticks_msec()
	var success: bool = await execute_simple_operation(
		"get_value_async", path.as_variants(), null, action_name
	)
	var operation_duration: int = Time.get_ticks_msec() - operation_start
	var total_duration: int = Time.get_ticks_msec() - start_time

	if success:
		return DebugAction.Result.new_success(
			"Successfully retrieved value from simple path",
			total_duration,
			action_name,
			{
				"test_type": "rtdb_get_simple_value",
				"path": path.as_variants(),
				"operation_duration_ms": operation_duration
			}
		)
	else:
		return DebugAction.Result.new_failure(
			"Failed to retrieve value from simple path",
			"GET_OPERATION_FAILED",
			DebugAction.Result.ErrorCategory.DATABASE,
			null,
			total_duration,
			action_name,
			{
				"test_type": "rtdb_get_simple_value",
				"path": path.as_variants(),
				"operation_duration_ms": operation_duration
			}
		)


# Legacy method for compatibility - delegates to new pattern
func execute_rtdb_action() -> bool:
	var result: DebugAction.Result = await _execute_action_logic({})
	return result.is_success()

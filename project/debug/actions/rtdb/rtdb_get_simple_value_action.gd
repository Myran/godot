class_name RTDBGetSimpleValueAction
extends RTDBDebugAction


func _init() -> void:
	super._init()
	action_name = "rtdb.database.get_value"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	var firebase_backend: Object = get_firebase_database()
	if not firebase_backend:
		return DebugActionResult.new_failure(
			"Firebase backend not available",
			"BACKEND_UNAVAILABLE",
			DebugActionResult.ErrorCategory.SYSTEM,
			null,
			Time.get_ticks_msec() - start_time,
			action_name
		)

	if not firebase_backend.is_available():
		return DebugActionResult.new_failure(
			"Firebase backend not initialized",
			"BACKEND_NOT_INITIALIZED",
			DebugActionResult.ErrorCategory.SYSTEM,
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
		return DebugActionResult.new_success(
			"Successfully retrieved value from simple path",
			total_duration,
			action_name,
			{
				"test_type": "rtdb_get_simple_value",
				"path": path.as_variants(),
				"operation_duration_ms": operation_duration
			}
		)

	return DebugActionResult.new_failure(
		"Failed to retrieve value from simple path",
		"GET_OPERATION_FAILED",
		DebugActionResult.ErrorCategory.DATABASE,
		null,
		total_duration,
		action_name,
		{
			"test_type": "rtdb_get_simple_value",
			"path": path.as_variants(),
			"operation_duration_ms": operation_duration
		}
	)


func execute_rtdb_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()

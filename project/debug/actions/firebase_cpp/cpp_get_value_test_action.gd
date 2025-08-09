class_name CPPGetValueTestAction
extends CPPFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.get_value"


func _execute_action_logic(_params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()

	var test_path: Array = ["cpp_tests", "direct", "get_value", str(Time.get_ticks_msec())]
	var test_value: String = "CPP Get Test Value: " + str(Time.get_ticks_msec())

	var set_start: int = Time.get_ticks_msec()
	var set_result: Variant = await execute_cpp_operation(
		"set_value_async", [test_path, test_value], "C++ Set (for Get test)", "set_value"
	)
	var set_duration: int = Time.get_ticks_msec() - set_start

	if not set_result:
		return DebugAction.Result.new_failure(
			"Failed to set test value for C++ get operation",
			"SET_OPERATION_FAILED",
			DebugAction.Result.ErrorCategory.FIREBASE,
			null,
			Time.get_ticks_msec() - start_time,
			action_name,
			{
				"test_type": "cpp_get_value",
				"step": "setup",
				"path": test_path,
				"set_duration_ms": set_duration
			}
		)

	var get_start: int = Time.get_ticks_msec()
	var get_result: Variant = await execute_cpp_operation(
		"get_value_async", [test_path], "C++ Get Value", "get_value"
	)
	var get_duration: int = Time.get_ticks_msec() - get_start
	var total_duration: int = Time.get_ticks_msec() - start_time

	var success: bool = get_result != null

	if success:
		return DebugAction.Result.new_success(
			"C++ get value operation successful",
			total_duration,
			action_name,
			{
				"test_type": "cpp_get_value",
				"path": test_path,
				"set_duration_ms": set_duration,
				"get_duration_ms": get_duration,
				"test_value": test_value,
				"retrieved_result": str(get_result)
			}
		)
	else:
		return DebugAction.Result.new_failure(
			"C++ get value operation failed",
			"GET_OPERATION_FAILED",
			DebugAction.Result.ErrorCategory.FIREBASE,
			null,
			total_duration,
			action_name,
			{
				"test_type": "cpp_get_value",
				"path": test_path,
				"set_duration_ms": set_duration,
				"get_duration_ms": get_duration,
				"test_value": test_value
			}
		)


func execute_cpp_action() -> bool:
	var result: DebugAction.Result = await _execute_action_logic({})
	return result.is_success()

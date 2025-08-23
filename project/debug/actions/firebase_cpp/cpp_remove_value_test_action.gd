class_name CPPRemoveValueTestAction
extends CPPFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.remove_value"


func _execute_action_logic(_params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()

	var test_path: Array = ["cpp_tests", "direct", "remove_value", str(Time.get_ticks_msec())]
	var test_value: String = "CPP Remove Test Value: " + str(Time.get_ticks_msec())

	var set_start: int = Time.get_ticks_msec()
	var set_result: Variant = await execute_cpp_operation(
		"set_value_async", [test_path, test_value], "C++ Set (for Remove test)", "set_value"
	)
	var set_duration: int = Time.get_ticks_msec() - set_start

	if not set_result:
		return DebugAction.Result.new_failure(
			"Failed to set test value for C++ remove operation",
			"SET_OPERATION_FAILED",
			DebugAction.Result.ErrorCategory.FIREBASE,
			null,
			Time.get_ticks_msec() - start_time,
			action_name,
			{
				"test_type": "cpp_remove_value",
				"step": "setup",
				"path": test_path,
				"set_duration_ms": set_duration
			}
		)

	var remove_start: int = Time.get_ticks_msec()
	var remove_result: Variant = await execute_cpp_operation(
		"remove_value_async", [test_path], "C++ Remove Value", "remove_value"
	)
	var remove_duration: int = Time.get_ticks_msec() - remove_start
	var total_duration: int = Time.get_ticks_msec() - start_time

	var success: bool = remove_result != null

	if success:
		return DebugAction.Result.new_success(
			"C++ remove value operation successful",
			total_duration,
			action_name,
			{
				"test_type": "cpp_remove_value",
				"path": test_path,
				"set_duration_ms": set_duration,
				"remove_duration_ms": remove_duration,
				"test_value": test_value,
				"remove_result": str(remove_result)
			}
		)

	return DebugAction.Result.new_failure(
		"C++ remove value operation failed",
		"REMOVE_OPERATION_FAILED",
		DebugAction.Result.ErrorCategory.FIREBASE,
		null,
		total_duration,
		action_name,
		{
			"test_type": "cpp_remove_value",
			"path": test_path,
			"set_duration_ms": set_duration,
			"remove_duration_ms": remove_duration,
			"test_value": test_value
		}
	)


func execute_cpp_action() -> bool:
	var result: DebugAction.Result = await _execute_action_logic({})
	return result.is_success()

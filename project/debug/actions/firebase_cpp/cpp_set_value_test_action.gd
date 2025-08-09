class_name CPPSetValueTestAction
extends CPPFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.set_value"


func _execute_action_logic(_params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()

	var test_path: Array[String] = ["cpp_tests", "direct", "set_value", str(Time.get_ticks_msec())]
	var test_value: String = "CPP Direct Value: " + str(Time.get_ticks_msec())

	var operation_start: int = Time.get_ticks_msec()
	var result: Variant = await execute_cpp_operation(
		"set_value_async", [test_path, test_value], "C++ Set Value", "set_value"
	)
	var operation_duration: int = Time.get_ticks_msec() - operation_start
	var total_duration: int = Time.get_ticks_msec() - start_time

	var success: bool = result != null

	if success:
		return DebugAction.Result.new_success(
			"C++ set value operation successful",
			total_duration,
			action_name,
			{
				"test_type": "cpp_set_value",
				"path": test_path,
				"set_value": test_value,
				"operation_duration_ms": operation_duration,
				"result": str(result)
			}
		)
	else:
		return DebugAction.Result.new_failure(
			"C++ set value operation failed",
			"SET_OPERATION_FAILED",
			DebugAction.Result.ErrorCategory.FIREBASE,
			null,
			total_duration,
			action_name,
			{
				"test_type": "cpp_set_value",
				"path": test_path,
				"attempted_value": test_value,
				"operation_duration_ms": operation_duration
			}
		)


func execute_cpp_action() -> bool:
	var result: DebugAction.Result = await _execute_action_logic({})
	return result.is_success()

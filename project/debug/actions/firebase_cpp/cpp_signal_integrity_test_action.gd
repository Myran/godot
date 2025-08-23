class_name CPPSignalIntegrityTestAction
extends CPPFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.signal_integrity"


func _execute_action_logic(_params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()
	_update_status("Testing C++ signal integrity...")

	var operations_count: int = 3
	var successful_operations: int = 0
	var total_duration: int = 0

	for i: int in range(operations_count):
		_update_status("C++ Signal test " + str(i + 1) + "/" + str(operations_count) + "...")

		var test_path: Array[String] = [
			"cpp_tests", "signal_integrity", str(i), str(Time.get_ticks_msec())
		]
		var test_value: String = "Signal Test " + str(i) + ": " + str(Time.get_ticks_msec())

		var operation_start: int = Time.get_ticks_msec()
		var result: Variant = await execute_cpp_operation(
			"set_value_async", [test_path, test_value], "Signal Integrity " + str(i), "set_value"
		)
		var duration: int = Time.get_ticks_msec() - operation_start

		if result:
			successful_operations += 1
			total_duration += duration
			Log.debug(
				"Signal integrity operation " + str(i) + " succeeded",
				{"duration_ms": duration},
				["debug", "cpp_firebase"]
			)
		else:
			Log.warning(
				"Signal integrity operation " + str(i) + " failed",
				{"duration_ms": duration},
				["debug", "cpp_firebase", "warning"]
			)

	var success_rate: float = float(successful_operations) / float(operations_count)
	var avg_duration: int = (
		int(float(total_duration) / float(operations_count)) if operations_count > 0 else 0
	)
	var success: bool = success_rate >= 0.8  # 80% success rate required
	var total_test_duration: int = Time.get_ticks_msec() - start_time

	var test_result: Dictionary = {
		"successful_operations": successful_operations,
		"total_operations": operations_count,
		"success_rate": success_rate,
		"avg_duration_ms": avg_duration,
		"overall_success": success
	}

	if success:
		_update_status(
			(
				"Signal integrity test PASSED ("
				+ str(successful_operations)
				+ "/"
				+ str(operations_count)
				+ ")"
			)
		)
		Log.info("C++ Signal integrity test passed", test_result, ["debug", "cpp_firebase"])
		return DebugAction.Result.new_success(
			"C++ signal integrity test passed", total_test_duration, action_name, test_result
		)

	_update_status(
		(
			"Signal integrity test FAILED ("
			+ str(successful_operations)
			+ "/"
			+ str(operations_count)
			+ ")"
		),
		true
	)
	Log.error("C++ Signal integrity test failed", test_result, ["debug", "cpp_firebase", "error"])
	return DebugAction.Result.new_failure(
		"C++ signal integrity test failed",
		"SIGNAL_INTEGRITY_FAILED",
		DebugAction.Result.ErrorCategory.FIREBASE,
		null,
		total_test_duration,
		action_name,
		test_result
	)


func execute_cpp_action() -> bool:
	var result: DebugAction.Result = await _execute_action_logic({})
	return result.is_success()

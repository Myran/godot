class_name CPPSignalIntegrityTestAction
extends CPPFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.signal_integrity"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Testing C++ signal integrity...")

	var operations_count: int = 3
	var successful_operations: int = 0
	var total_duration: int = 0
	var operation_results: Array = []

	# Perform signal integrity operations sequentially with timing
	for i: int in range(operations_count):
		_update_status("C++ Signal test " + str(i + 1) + "/" + str(operations_count) + "...")

		var test_path: Array[String] = TestUtils.make_test_path(
			TestConstants.FIREBASE_CPP_PREFIX, "signal_integrity_" + str(i)
		)
		var test_value: String = TestConstants.test_value("Signal Test " + str(i))

		# Time each individual operation
		var operation: Dictionary = await TestUtils.time_operation(
			"signal_op_" + str(i),
			func() -> Variant:
				return await execute_cpp_operation(
					TestConstants.FIREBASE_OPERATIONS.SET_VALUE,
					[test_path, test_value],
					TestConstants.operation_description("Signal Integrity", str(i)),
					"set_value"
				)
		)

		var op_success: bool = TestValidation.validate_firebase_result(
			operation.result, "signal_integrity_" + str(i)
		)
		if op_success:
			successful_operations += 1
			total_duration += TestUtils.get_duration_ms(operation)
			Log.debug(
				"Signal integrity operation " + str(i) + " succeeded",
				{"duration_ms": TestUtils.get_duration_ms(operation)},
				["debug", "cpp_firebase"]
			)
		else:
			Log.warning(
				"Signal integrity operation " + str(i) + " failed",
				{"duration_ms": TestUtils.get_duration_ms(operation)},
				["debug", "cpp_firebase", "warning"]
			)

		operation_results.append(
			{
				"operation_id": i,
				"success": op_success,
				"duration_ms": TestUtils.get_duration_ms(operation)
			}
		)

	var success_rate: float = float(successful_operations) / float(operations_count)
	var avg_duration: int = (
		int(float(total_duration) / float(operations_count)) if operations_count > 0 else 0
	)
	var success: bool = success_rate >= 0.8  # 80% success rate required

	var test_result: Dictionary = TestUtils.make_metadata(
		TestConstants.TEST_TYPES.CPP_SIGNAL_INTEGRITY,
		{
			"successful_operations": successful_operations,
			"total_operations": operations_count,
			"success_rate": success_rate,
			"avg_duration_ms": avg_duration,
			"overall_success": success,
			"operations": operation_results
		}
	)

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
		return TestUtils.make_success_result(
			"C++ signal integrity test passed", total_duration, action_name, test_result
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
	return TestUtils.make_failure_result(
		"C++ signal integrity test failed",
		TestConstants.ERROR_CODES.SIGNAL_INTEGRITY_FAILED,
		total_duration,
		action_name,
		test_result
	)


func execute_cpp_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()

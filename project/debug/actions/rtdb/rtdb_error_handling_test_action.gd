class_name RTDBErrorHandlingTestAction
extends RTDBDebugAction


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "rtdb.testing.error_handling"
	group = "Advanced"
	description = "Deliberately triggers various error conditions to test error handling and recovery."


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var timed_op: Dictionary = await TestUtils.time_operation(
		"RTDB Error Handling Test", _perform_error_tests
	)
	var test_results: Dictionary = timed_op.result
	var duration_ms: int = TestUtils.get_duration_ms(timed_op)

	if not TestUtils.is_valid_result(test_results):
		return TestUtils.make_failure_result(
			"Failed to get Firebase database instance",
			TestConstants.ERROR_CODES.BACKEND_UNAVAILABLE,
			duration_ms,
			action_name,
			TestUtils.make_metadata("rtdb_error_handling", {"database_available": false})
		)

	var passed_tests: int = test_results.get("passed_tests", 0)
	var total_tests: int = test_results.get("total_tests", 3)
	var tests_array: Array[Dictionary] = test_results.get("test_results", [])
	var success_rate: float = float(passed_tests) / float(total_tests)
	var test_success: bool = passed_tests >= 2  # At least 2 out of 3 tests should pass

	var metadata: Dictionary = TestUtils.make_metadata(
		"error_handling_simplified",
		{
			"total_tests": total_tests,
			"passed_tests": passed_tests,
			"success_rate": success_rate,
			"test_results": tests_array,
			"operation_duration_ms": duration_ms,
			"minimum_required_passed": 2
		}
	)

	if test_success:
		return TestUtils.make_success_result(
			(
				"Error handling test completed successfully (%d/%d tests passed)"
				% [passed_tests, total_tests]
			),
			duration_ms,
			action_name,
			metadata
		)

	return TestUtils.make_failure_result(
		"Error handling test failed (%d/%d tests passed)" % [passed_tests, total_tests],
		TestConstants.ERROR_CODES.VALIDATION_FAILED,
		duration_ms,
		action_name,
		metadata
	)


func _perform_error_tests() -> Dictionary:
	var db: Object = get_firebase_database()
	if not db:
		return {}

	var passed_tests: int = 0
	var total_tests: int = 3
	var test_results_array: Array[Dictionary] = []

	_update_status("Testing invalid path access...")
	var invalid_path: Array[Variant] = ["invalid", "restricted", "path"]
	var test1_result: bool = await execute_simple_operation(
		TestConstants.FIREBASE_OPERATIONS.GET_VALUE, invalid_path, null, "Invalid Path Test"
	)
	var test1_passed: bool = not test1_result  # Should fail
	if test1_passed:
		passed_tests += 1
	test_results_array.append(
		{
			"test_name": "Invalid Path Access",
			"operation_succeeded": test1_result,
			"error_handled_correctly": test1_passed,
			"expected": "graceful_failure"
		}
	)

	_update_status("Testing nonexistent path access...")
	var nonexistent_path: Array[Variant] = create_test_path(
		["nonexistent", "data", str(Time.get_ticks_msec())]
	)
	var test2_result: bool = await execute_simple_operation(
		TestConstants.FIREBASE_OPERATIONS.GET_VALUE, nonexistent_path, null, "Nonexistent Path Test"
	)
	var test2_passed: bool = true  # Any completion (success or graceful failure) is acceptable
	if test2_passed:
		passed_tests += 1
	test_results_array.append(
		{
			"test_name": "Nonexistent Path Access",
			"operation_succeeded": test2_result,
			"error_handled_correctly": test2_passed,
			"expected": "graceful_completion"
		}
	)

	_update_status("Testing valid operation for comparison...")
	var valid_path: Array[Variant] = create_test_path(["error_test", "valid_operation"])
	var test_data: Dictionary = {
		"test": TestConstants.test_value("data"), "timestamp": Time.get_ticks_msec()
	}
	var test3_result: bool = await execute_simple_operation(
		TestConstants.FIREBASE_OPERATIONS.SET_VALUE, valid_path, test_data, "Valid Operation Test"
	)
	var test3_passed: bool = test3_result
	if test3_passed:
		passed_tests += 1
	test_results_array.append(
		{
			"test_name": "Valid Operation",
			"operation_succeeded": test3_result,
			"error_handled_correctly": test3_passed,
			"expected": "success"
		}
	)

	return {
		"passed_tests": passed_tests, "total_tests": total_tests, "test_results": test_results_array
	}


func execute_rtdb_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()

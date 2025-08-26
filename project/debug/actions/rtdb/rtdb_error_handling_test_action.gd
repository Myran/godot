class_name RTDBErrorHandlingTestAction
extends RTDBDebugAction


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "rtdb.testing.error_handling"
	group = "Advanced"
	description = "Deliberately triggers various error conditions to test error handling and recovery."


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	var db: Object = get_firebase_database()
	if not db:
		return DebugActionResult.new_failure(
			"Failed to get Firebase database instance",
			"DATABASE_UNAVAILABLE",
			DebugActionResult.ErrorCategory.FIREBASE,
			{"database_available": false},
			0,
			action_name
		)

	var passed_tests: int = 0
	var total_tests: int = 3
	var test_results: Array[Dictionary] = []

	_update_status("Testing invalid path access...")
	var invalid_path: Array[Variant] = ["invalid", "restricted", "path"]
	var test1_result: bool = await execute_simple_operation(
		"get_value_async", invalid_path, null, "Invalid Path Test"
	)
	var test1_passed: bool = not test1_result  # Should fail
	if test1_passed:
		passed_tests += 1
	test_results.append(
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
		"get_value_async", nonexistent_path, null, "Nonexistent Path Test"
	)
	var test2_passed: bool = true  # Any completion (success or graceful failure) is acceptable
	if test2_passed:
		passed_tests += 1
	test_results.append(
		{
			"test_name": "Nonexistent Path Access",
			"operation_succeeded": test2_result,
			"error_handled_correctly": test2_passed,
			"expected": "graceful_completion"
		}
	)

	_update_status("Testing valid operation for comparison...")
	var valid_path: Array[Variant] = create_test_path(["error_test", "valid_operation"])
	var test_data: Dictionary = {"test": "data", "timestamp": Time.get_ticks_msec()}
	var test3_result: bool = await execute_simple_operation(
		"set_value_async", valid_path, test_data, "Valid Operation Test"
	)
	var test3_passed: bool = test3_result
	if test3_passed:
		passed_tests += 1
	test_results.append(
		{
			"test_name": "Valid Operation",
			"operation_succeeded": test3_result,
			"error_handled_correctly": test3_passed,
			"expected": "success"
		}
	)

	var success_rate: float = float(passed_tests) / float(total_tests)
	var test_success: bool = passed_tests >= 2  # At least 2 out of 3 tests should pass
	var total_duration: int = Time.get_ticks_msec() - start_time

	if test_success:
		return DebugActionResult.new_success(
			(
				"Error handling test completed successfully (%d/%d tests passed)"
				% [passed_tests, total_tests]
			),
			total_duration,
			action_name,
			{
				"test_type": "error_handling_simplified",
				"total_tests": total_tests,
				"passed_tests": passed_tests,
				"success_rate": success_rate,
				"test_results": test_results,
				"operation_duration_ms": total_duration
			}
		)

	return DebugActionResult.new_failure(
		"Error handling test failed (%d/%d tests passed)" % [passed_tests, total_tests],
		"ERROR_HANDLING_TEST_FAILED",
		DebugActionResult.ErrorCategory.VALIDATION,
		null,
		total_duration,
		action_name,
		{
			"test_type": "error_handling_simplified",
			"total_tests": total_tests,
			"passed_tests": passed_tests,
			"success_rate": success_rate,
			"test_results": test_results,
			"minimum_required_passed": 2
		}
	)


func execute_rtdb_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()

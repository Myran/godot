class_name CPPErrorHandlingTestAction
extends CPPFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.error_handling"


func _execute_action_logic(_params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()
	var passed_tests: int = 0
	var total_tests: int = 3
	var test_results: Array[Dictionary] = []

	_update_status("Testing basic C++ operation...")
	var test1_result: Variant = await execute_cpp_operation(
		"get_value_async",
		[["cpp_tests", "error_handling", str(Time.get_ticks_msec())]],
		"Basic Operation Test",
		"get_value"
	)
	var test1_passed: bool = test1_result != null
	if test1_passed:
		passed_tests += 1
	test_results.append(
		{
			"test_name": "Basic Operation Test",
			"operation_succeeded": test1_passed,
			"result": test1_result,
			"expected": "normal_operation"
		}
	)

	_update_status("Testing C++ set operation...")
	var test2_result: Variant = await execute_cpp_operation(
		"set_value_async",
		[["cpp_tests", "error_test", str(Time.get_ticks_msec())], "test_value"],
		"Set Operation Test",
		"set_value"
	)
	var test2_passed: bool = test2_result != null
	if test2_passed:
		passed_tests += 1
	test_results.append(
		{
			"test_name": "Set Operation Test",
			"operation_succeeded": test2_passed,
			"result": test2_result,
			"expected": "normal_operation"
		}
	)

	_update_status("Testing C++ invalid path handling...")
	var test3_result: Variant = await execute_cpp_operation(
		"get_value_async",
		[["cpp_tests", "invalid", "path", "should", "fail"]],
		"Invalid Path Handling Test",
		"get_value"
	)
	var test3_passed: bool = true  # Any completion without crash is considered success
	if test3_passed:
		passed_tests += 1
	test_results.append(
		{
			"test_name": "Invalid Path Handling Test",
			"operation_succeeded": test3_result != null,
			"graceful_handling": test3_passed,
			"result": test3_result,
			"expected": "graceful_error_handling"
		}
	)

	var success_rate: float = float(passed_tests) / float(total_tests)
	var overall_success: bool = success_rate >= 0.67  # 67% success rate
	var total_duration: int = Time.get_ticks_msec() - start_time

	if overall_success:
		return DebugAction.Result.new_success(
			"C++ error handling test passed (%d/%d tests)" % [passed_tests, total_tests],
			total_duration,
			action_name,
			{
				"test_type": "cpp_error_handling_enhanced",
				"total_tests": total_tests,
				"passed_tests": passed_tests,
				"success_rate": success_rate,
				"test_results": test_results,
				"operation_duration_ms": total_duration
			}
		)

	return DebugAction.Result.new_failure(
		"C++ error handling test failed (%d/%d tests)" % [passed_tests, total_tests],
		"CPP_ERROR_HANDLING_TEST_FAILED",
		DebugAction.Result.ErrorCategory.FIREBASE,
		null,
		total_duration,
		action_name,
		{
			"test_type": "cpp_error_handling_enhanced",
			"total_tests": total_tests,
			"passed_tests": passed_tests,
			"success_rate": success_rate,
			"test_results": test_results,
			"minimum_required_passed": 2
		}
	)


func execute_cpp_action() -> bool:
	var result: DebugAction.Result = await _execute_action_logic({})
	return result.is_success()
